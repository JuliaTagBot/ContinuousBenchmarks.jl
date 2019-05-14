module Reporter

using GitHub
using Base64
using Pkg

using ..Config
using ..Utils

const app_repo = Config.get_config("github.app_repo")
if get(ENV, "ENV", "priv") == "travis"
    const bot_token = get(ENV, "GITHUB_TOKEN", "none")
else
    const bot_token = Config.get_config("github.token")
end

function send(benchmark, bm_info, report_file)
    bot_auth = GitHub.authenticate(bot_token)
    name = benchmark

    # 1. commit the report
    content = open(report_file) do io read(io, String) end
    content = base64encode(content)
    params = Dict("branch" => name,
                  "message" => "[skip ci] $(name) Report",
                  "content" => content)

    commit = GitHub.create_file(app_repo, "jobs/$(name).report.md";
                                params=params, auth=bot_auth)
    commit_id = commit["commit"].sha
    report_url = "https://github.com/$app_repo/blob/$name/" *
        "jobs/$(name).report.md"

    # 2. find the tracking PR, comment on it
    all_prs = GitHub.pull_requests(app_repo; auth=bot_auth)
    tracking_pr = nothing
    for item in  all_prs[1]
        if item.title == name
            tracking_pr = item
            params = Dict("body" => Utils.bm_pr_report_content(commit_id, report_url))
            create_comment(app_repo, item.number, :pr; params=params, auth=bot_auth)
            break
        end
    end

    # 3. find the trigger issue, comment it
    issue_url = bm_info["trigger"]["issue_url"]
    user = bm_info["trigger"]["user"]
    reg = r".*://github.com/([^/]+/[^/]+)/issues/(\d+)"
    m = match(reg, issue_url)
    params = Dict("body" => Utils.bm_reply1_content(name, user, app_repo, commit_id, report_url))
    create_comment(m[1], parse(Int, m[2]), :issue; params=params, auth=bot_auth)
end

function write_report!(bm_name, filename, branches::Vector, shas::Vector, base_branch="")
    report_md = generate_report(bm_name, branches, shas, base_branch)
    result_path = joinpath(result_dir(bm_name), filename)
    write(result_path, report_md)
end

end
