module AppServer

using Sockets
using GitHub
using HTTP
using Base64
using Pkg
using Logging

using ..Config
using ..Utils
using ..Runner

const event_queue = Channel{Any}(1024)
const httpsock = Ref{Sockets.TCPServer}()

const app_repo = Config.get_config("github.app_repo")
const app_repo_bmbr = Config.get_config("github.app_repo_bmbr")
const bot_user = Config.get_config("github.user")

function bm_from_comment(data)
    data.payload["action"] != "created" && return

    bot_auth = GitHub.authenticate(Config.get_config("github.token"))

    comment_url = data.payload["comment"]["html_url"]
    comment_body = data.payload["comment"]["body"]
    issue_no = data.payload["issue"]["number"]
    issue_url = data.payload["issue"]["html_url"]
    issue_repo = data.repository

    occursin("@TuringBenchBot", comment_body) || return
    branches = benchmark_branches(comment_body)
    if isempty(branches)
        params = Dict("body" => "Yes Sir?")
        create_comment(issue_repo, issue_no, :issue; params=params, auth=bot_auth)
        return
    end
    name = bm_name(branches)
    content = base64encode(Utils.bm_file_content(issue_url, comment_url, branches))
    params = Dict("branch" => app_repo_bmbr,
                  "message" => name,
                  "content" => content)

    commit = GitHub.create_file(app_repo, "jobs/$(name).toml"; params=params, auth=bot_auth)

    commit_id = commit["commit"].sha
    params = Dict("title"=>name, "body"=>Utils.bm_issue_content(commit_id, comment_url))
    issue = create_issue(app_repo; params=params, auth=bot_auth)

    params = Dict("body" => Utils.bm_reply0_content(issue.html_url.uri))
    create_comment(issue_repo, issue_no, :issue; params=params, auth=bot_auth)
end

function handle_events(e)
    @debug("Handle Event: ", e)
    e.kind == "issue_comment" && return bm_from_comment(e)
    e.kind == "push" && Config.get_config("server.bm_runner") == "self" &&
        return Runner.trigger(e)
end

function event_handler(event::WebhookEvent)
    global event_queue
    @debug("Received event for $(event.repository.full_name)")
    push!(event_queue, event)
    @debug("event pushed")
    return HTTP.Messages.Response(200)
end

function comment_handler(event::WebhookEvent, phrase::RegexMatch)
    global event_queue
    @debug("Received event for $(event.repository.full_name), phrase: $phrase")
    push!(event_queue, event)
    @debug("event pushed")
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
    @warn("Stopped", name)
end

function request_processor()
    do_action() = begin
        event = take!(event_queue)
        tsk = @task handle_events(event)
        schedule(tsk)
    end
    handle_exception(ex) =
        (isa(ex, InvalidStateException) && (ex.state == :closed)) ? :exit : :continue
    keep_running() = isopen(event_queue)
    recover("request_processor", keep_running, do_action, handle_exception)
end

function github_webhook(
    http_ip=Config.get_config("server.http_ip"),
    http_port=Config.get_config("server.http_port")
)
    app_auth = GitHub.JWTAuth(
        Config.get_config("github.app_id"), Config.get_config("github.priv_pem"))
    # trigger = Regex("@TuringBenchBot")
    # listener = GitHub.CommentListener(
    #    comment_handler,
    #    trigger;
    #    check_collab=false,
    #    auth=app_auth,
    #    secret=Config.get_config("github.secret"))

    listener = GitHub.EventListener(
        event_handler,
        auth=app_auth,
        secret=Config.get_config("github.secret"),
        events=["push", "issue_comment"])
    httpsock[] = Sockets.listen(IPv4(http_ip), http_port)

    do_action() = GitHub.run(listener, httpsock[], IPv4(http_ip), http_port, verbose=true)
    handle_exception(ex) = (isa(ex, Base.IOError) && (ex.code == -103)) ? :exit : :continue
    keep_running() = isopen(httpsock[])

    @info("GitHub Webhook starting...", http_ip, http_port)
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

    global_logger(SimpleLogger(stdout, Config.log_level()))

    @info("Starting server...")
    handler_task = @async request_processor()
    monitor_task = @async status_monitor()
    github_webhook()
    wait(handler_task)
    wait(monitor_task)
    @warn("Server stopped.")
end

end
