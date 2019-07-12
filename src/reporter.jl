module Reporter

using Base64
using CSV
using DataFrames
using GitHub
using JSON
using Pkg

using ..Config
using ..Utils

export log_report

const report_repo = Config.get_config("github.report_repo")
const report_branch = Config.get_config("github.report_branch", "master")
const target_repo = Config.get_config("target.repo")

if get(ENV, "TRAVIS", "false") == "true"
    const bot_token = get(ENV, "BenchmarkBot_GITHUB_TOKEN", "none")
else
    const bot_token = Config.get_config("github.token")
end


function _log_report()
    logs = Vector{String}()
    project_dir = if Base.JLOptions().project == C_NULL
        pwd()
    else
        unsafe_string(Base.JLOptions().project)
    end
    log_report = (log::String...) -> begin
        isempty(log) && return logs
        commit_id = snip7(githeadsha(project_dir))
        log = map(log) do x "[$commit_id] " * x end
        push!(logs, log...)
    end
    log_save = (file, save_path) -> begin
        log_text = join(logs, "\n")
        cd(() -> write(file, log_text), save_path)
    end
    return (log_report, log_save)
end
log_report, _log_save = _log_report()

function send(benchmark, bm_info, report_file)
    bot_auth = GitHub.authenticate(bot_token)
    name = benchmark

    # 1. commit the report
    content = open(report_file) do io read(io, String) end
    content = base64encode(content)
    params = Dict("branch" => name,
                  "message" => "[skip ci] $(name) Report",
                  "content" => content)

    commit = GitHub.create_file(report_repo, "jobs/$(name).report.md";
                                params=params, auth=bot_auth)
    commit_id = commit["commit"].sha
    report_url = "https://github.com/$report_repo/blob/$name/" *
        "jobs/$(name).report.md"

    # 2. find the tracking PR, comment on it
    all_prs = GitHub.pull_requests(report_repo; auth=bot_auth)
    tracking_pr = nothing
    for item in  all_prs[1]
        if item.title == name
            tracking_pr = item
            params = Dict(
                "body" => Utils.bm_pr_report_content(name, commit_id, report_url)
            )
            create_comment(report_repo, item.number, :pr; params=params, auth=bot_auth)
            break
        end
    end

    # 3. find the trigger issue, comment it
    issue_url = bm_info["trigger"]["issue_url"]
    user = bm_info["trigger"]["user"]
    reg = r".*://github.com/([^/]+/[^/]+)/issues/(\d+)"
    m = match(reg, issue_url)
    params = Dict(
        "body" => Utils.bm_reply1_content(name, user, report_repo, commit_id, report_url)
    )
    create_comment(m[1], parse(Int, m[2]), :issue; params=params, auth=bot_auth)
end

function send_from_travis(benchmark, triggerer_cid, report_file)
    bot_auth = GitHub.authenticate(bot_token)
    name = benchmark

    # 1. commit the report
    content = open(report_file) do io read(io, String) end
    content = base64encode(content)
    params = Dict("branch" => report_branch,
                  "message" => "[skip ci] $(name) Report",
                  "content" => content)

    commit = GitHub.create_file(report_repo, "jobs/$(name).report.md";
                                params=params, auth=bot_auth)
    commit_id = commit["commit"].sha
    report_url = "https://github.com/$report_repo/blob/$report_branch/" *
        "jobs/$(name).report.md"

    # 2. find the trigger commit, comment on it
    params = Dict(
        "body" => Utils.bm_commit_report_content(name, commit_id, report_url)
    )
    create_comment(target_repo, triggerer_cid, :commit; params=params, auth=bot_auth)
end


function send_error(benchmark, bm_info, exc)
    bot_auth = GitHub.authenticate(bot_token)
    name = benchmark

    # 1. find the tracking PR, comment on it
    all_prs = GitHub.pull_requests(report_repo; auth=bot_auth)
    tracking_pr = nothing
    for item in  all_prs[1]
        if item.title == name
            tracking_pr = item
            params = Dict("body" => Utils.bm_pr_error_content(exc))
            create_comment(report_repo, item.number, :pr; params=params, auth=bot_auth)
            break
        end
    end

    # 2. find the trigger issue, comment it
    issue_url = bm_info["trigger"]["issue_url"]
    user = bm_info["trigger"]["user"]
    reg = r".*://github.com/([^/]+/[^/]+)/issues/(\d+)"
    m = match(reg, issue_url)
    params = Dict("body" => Utils.bm_reply2_content(name, user, report_repo, exc))
    create_comment(m[1], parse(Int, m[2]), :issue; params=params, auth=bot_auth)
end

function save_result(log_data::Dict, source::String, path::String)
    if !haskey(log_data, "name")
        log_data["name"] = basename(source)
    end
    if Config.get_config("reporter.use_dataframe", false)
        return save_result(DataFrame(log_data), source, path)
    end
    result_file = Utils.result_filename(log_data) * ".json"
    cd(() -> write(result_file, JSON.json(log_data, 2)), path)
end

function save_result(log_data::DataFrame, source::String, path::String)
    if !in(:name, names(log_data))
        row_count = size(log_data)[1]
        name_col= DataFrame(name=repeat([basename(source)], row_count))
        log_data = hcat(name_col, log_data)
    end
    result_file = Utils.result_filename(log_data) * ".csv"
    cd(() -> CSV.write(result_file, log_data), path)
end

function save_log(log_data::Union{Dict, DataFrame}, path::String)
    if Config.get_config("reporter.use_dataframe", false) && isa(log_data, Dict)
        log_data = DataFrame(log_data)
    end
    log_file = Utils.result_filename(log_data) * ".log"
    _log_save(log_file, path)
end

function write_report!(bm_name, filename, branches::Vector, shas::Vector, base_branch="")
    if Config.get_config("reporter.use_dataframe", false)
        report_md = generate_report_dataframe(bm_name, branches, shas, base_branch)
    else
        report_md = generate_report(bm_name, branches, shas, base_branch)
    end
    result_path = joinpath(result_dir(bm_name), filename)
    write(result_path, report_md)
end

end
