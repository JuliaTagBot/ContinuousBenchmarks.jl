module AppServer

using Sockets
using GitHub
using HTTP
using Pkg

using ..Config

const event_queue = Channel{Any}(1024)
const httpsock = Ref{Sockets.TCPServer}()

function handle_events(e)
    # TODO
    @info("Handle Event: ", e)
end

function comment_handler(event::WebhookEvent, phrase::RegexMatch)
    global event_queue
    @debug("Received event for $(event.repository.full_name), phrase: $phrase")
    push!(event_queue, event)
    return HTTP.Messages.Response(200)
end

function recover(name, keep_running, do_action, handle_exception;
                 backoff=0, backoffmax=120, backoffincrement=1)
    while keep_running()
        try
            do_action()
            backoff = 0
        catch ex
            exception_action = handle_exception(ex)
            if exception_action == :exit
                @warn("Stopping", name)
                return
            else # exception_action == :continue
                bt = get_backtrace(ex)
                @error("Recovering from unknown exception", name, ex, bt, backoff)
                sleep(backoff)
                backoff = min(backoffmax, backoff+backoffincrement)
            end
        end
    end
end

function request_processor()
    do_action() = handle_events(take!(event_queue))
    handle_exception(ex) =
        (isa(ex, InvalidStateException) && (ex.state == :closed)) ? :exit : :continue
    keep_running() = isopen(event_queue)
    recover("request_processor", keep_running, do_action, handle_exception)
end

function github_webhook(
    http_ip=Config.get_config("server.http_ip"),
    http_port=Config.get_config("server.http_port")
)    
    auth = GitHub.JWTAuth(Config.get_config("github.app_id"), Config.get_config("github.priv_pem"))
    trigger = Regex(".*")
    listener = GitHub.CommentListener(
        comment_handler,
        trigger;
        check_collab=false,
        auth=auth,
        secret=Config.get_config("github.secret"))

    httpsock[] = Sockets.listen(IPv4(http_ip), http_port)

    do_action() = GitHub.run(listener, httpsock[], IPv4(http_ip), http_port, verbose=true)
    handle_exception(ex) = (isa(ex, Base.IOError) && (ex.code == -103)) ? :exit : :continue
    keep_running() = isopen(httpsock[])

    @info("GitHub Webhook starting...", trigger, http_ip, http_port)
    recover("github_webhook", keep_running, do_action, handle_exception)
end

function status_monitor()
    stop_file = config["server"]["stop_file"]
    while isopen(event_queue)
        sleep(5)
        flush(stdout); flush(stderr);
        # stop server if stop is requested
        if isfile(stop_file)
            @warn("Server stop requested.")
            flush(stdout); flush(stderr)
            # stop accepting new requests
            close(httpsock[])
            # wait for queued requests to be processed and close queue
            while isready(event_queue)
                yield()
            end
            close(event_queue)
            rm(stop_file; force=true)
        end
    end
end

function main()
    if isempty(get(ENV, "ENV", ""))
        println("Usage: \n\t" *
                "export ENV=dev|prod|...\n\t"*
                "julia -e 'using TuringBenchmarks; TuringBenchmarks.AppServer.main()' ")
        return
    end

    @info("Starting server...")
    handler_task = @async request_processor()
    monitor_task = @async status_monitor()
    github_webhook()
    wait(handler_task)
    wait(monitor_task)
    @warn("Server stopped.")
end

end
