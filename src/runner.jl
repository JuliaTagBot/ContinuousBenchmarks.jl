module Runner

using Pkg
using GitHub
using Base64

using ..Reporter
using ..TuringBot
using ..Config

const app_repo = Config.get_config("github.app_repo")
const app_repo_bmbr = Config.get_config("github.app_repo_bmbr")

function trigger(push_event)
    commit = push_event.payload["head_commit"]
    commit_id =  commit["id"]
    commit_msg = commit["message"]
    reg = r"^BM-\d{12}.*"
    @debug "Begin to run benchmark $commit_msg..."
    if match(reg, commit_msg) != nothing
        run(commit_msg)
    end
end

function run(name)
    bot_auth = GitHub.authenticate(Config.get_config("github.token"))
    params = Dict("ref" => app_repo_bmbr)
    bm_file_content = GitHub.file(app_repo, "jobs/$(name).toml"; params=params, auth=bot_auth)
    content = String(base64decode(replace(bm_file_content.content, "\n" =>"")))
    bm_info = Pkg.TOML.parse(content)
    report_path = TuringBot.local_benchmark(bm_info["benchmark"]["branches"])
    Reporter.send(name, bm_info, report_path)
end

end
