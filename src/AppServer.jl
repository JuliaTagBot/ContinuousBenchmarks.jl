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
using ..ContinuousBenchmarks: set_benchmark_config_file

const event_queue = Channel{Any}(1024)
const httpsock = Ref{Sockets.TCPServer}()

const report_repo = Config.get_config("github.report_repo")
const report_branch = Config.get_config("github.report_branch", "master")
const bot_user = Config.get_config("github.user")

function bm_from_comment(data)
    data.payload["action"] != "created" && return

    bot_auth = GitHub.authenticate(Config.get_config("github.token"))

    comment_url = data.payload["comment"]["html_url"]
    comment_body = data.payload["comment"]["body"]
    user = data.payload["comment"]["user"]["login"]
    issue_no = data.payload["issue"]["number"]
    issue_url = data.payload["issue"]["html_url"]
    issue_repo = data.repository

    occursin("@$bot_user", comment_body) || return
    branches = benchmark_branches(comment_body)
    if isempty(branches)
        params = Dict("body" => "@$user Yes Sir?")
        create_comment(issue_repo, issue_no, :issue; params=params, auth=bot_auth)
        return
    end
    try
        gitbranches(Config.get_config("target.project_dir", "."), branches)
    catch ex # not all of the branches exist
        params = Dict("body" => "@$user $ex")
        create_comment(issue_repo, issue_no, :issue; params=params, auth=bot_auth)
        return
    end

    name = bm_name(branches)

    # create the branch
    base_br = GitHub.reference(report_repo, "heads/$report_branch"; auth=bot_auth)
    params = Dict("ref" => "refs/heads/" * name, "sha" => base_br.object["sha"])
    GitHub.create_reference(report_repo; params=params, auth=bot_auth)

    # commit bm info file on the new branch
    content = base64encode(Utils.bm_file_content(user, issue_url, comment_url, branches))
    params = Dict("branch" => name,
                  "message" => name,
                  "content" => content)
    commit = GitHub.create_file(report_repo, "jobs/$(name).toml"; params=params, auth=bot_auth)

    # create pull request
    params = Dict("title" => name,
                  "head" => name,
                  "base" => report_branch,
                  "body" => Utils.bm_pr_content(comment_url))
    pr = GitHub.create_pull_request(report_repo; params=params, auth=bot_auth)

    params = Dict("body" => Utils.bm_reply0_content(user, pr.html_url.uri))
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
    # trigger = Regex("@$bot_user")
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
    if isempty(get(ENV, "ENV", "")) && isempty(get(ENV, "TBB_CONFIG", ""))
        println("Usage: \n\t" *
                "export TBB_CONFIG=/path/to/config/file # or export ENV=dev|prod|...\n\t" *
                "julia -e 'using ContinuousBenchmarks; ContinuousBenchmarks.AppServer.main()' ")
        return
    end

    global_logger(SimpleLogger(stdout, Config.log_level()))

    project_dir = Config.get_config("target.project_dir")
    benchmark_config_file = Config.get_config("target.benchmark_config_file")
    set_benchmark_config_file(joinpath(project_dir, benchmark_config_file))

    @info("Starting server...")
    handler_task = @async request_processor()
    monitor_task = @async status_monitor()
    github_webhook()
    wait(handler_task)
    wait(monitor_task)
    @warn("Server stopped.")
end

end
