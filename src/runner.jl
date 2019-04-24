module Runner

using Pkg

using ..Reporter
using ..TuringBot

function trigger(push_event)
    commit = push_event.payload["head_commit"]
    commit_id =  commit["id"]
    commit_msg = commit["message"]
    reg = r"^BM-\d{12}.*"
    @debug "Begin to run benchmark $commit_msg..."
    #TODO: go a git pull to fetch the bm.toml
    if match(reg, commit_msg) != nothing
        run(commit_msg)
    end
end

function run(name)
    bm_file = joinpath((@__DIR__), "../jobs/$(name).toml")
    bm_file = joinpath((@__DIR__), "../test.bm.toml") # TODO: remove this line
    bm_info = Pkg.TOML.parsefile(bm_file)
    report_path = TuringBot.local_benchmark(bm_info["benchmark"]["branches"])
    Reporter.send(name, bm_info, report_path)
end

end
