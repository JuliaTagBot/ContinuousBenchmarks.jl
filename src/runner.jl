module Runner

using Pkg
using GitHub
using Base64

using ..Reporter
using ..TuringBot
using ..Config

using ..TuringBenchmarks: BENCH_DIR, should_run_benchmark,
    benchmark_files


const app_repo = Config.get_config("github.app_repo")
const app_repo_bmbr = Config.get_config("github.app_repo_bmbr")

function trigger(push_event)
    commit = push_event.payload["head_commit"]
    commit_id =  commit["id"]
    commit_msg = commit["message"]
    reg = r"^BM-\d{12}.*"
    @debug "Begin to run benchmark $commit_msg..."
    if match(reg, commit_msg) != nothing
        run_bm(commit_msg)
    end
end

function run_bm(name::String)
    bot_auth = GitHub.authenticate(Config.get_config("github.token"))
    params = Dict("ref" => app_repo_bmbr)
    bm_file_content = GitHub.file(app_repo, "jobs/$(name).toml"; params=params, auth=bot_auth)
    content = String(base64decode(replace(bm_file_content.content, "\n" =>"")))
    bm_info = Pkg.TOML.parse(content)
    report_path = local_benchmark(name, bm_info["benchmark"]["branches"])
    Reporter.send(name, bm_info, report_path)
end


drop2(x) = x[3:end]

function gitcurrentbranch()
    branches = readlines(`git branch`)
    ind = findfirst(x -> x[1] == '*', branches)
    return drop2(branches[ind])
end
gitcurrentbranch(path) = cd(gitcurrentbranch, path)

function gitbranches(branches)
    currentbranch = gitcurrentbranch()
    all_branches = drop2.(readlines(`git branch -al`))
    for brch in branches
        (brch in all_branches) && continue
        br_idx = findfirst(all_branches) do b endswith(b, "/" * brch) end
        br_idx == nothing && throw("Branch $brch not found.")
        run(`git checkout -b $brch $(all_branches[br_idx])`)
    end
    run(`git checkout $currentbranch`)
end
gitbranches(path, branches) = cd(() -> gitbranches(branches), path)

function onbranch(f::Function, repopath, branch)
    cd(repopath) do
        currentbranch = gitcurrentbranch()
        currentbranch != branch && run(`git checkout $branch`)
        f()
        currentbranch != branch && run(`git checkout $currentbranch`)
    end
end

getbranchsha(branch) = strip(read(`git rev-parse $branch`, String))
getbranchsha(path, branch) = cd(()-> getbranchsha(branch), path)
getbranchshas(path, branches) = getbranchsha.((path,), branches)


function turingpath()
    juliaexe_path = joinpath(Sys.BINDIR, Base.julia_exename())
    turing_jl = readchomp(`$(juliaexe_path) -e "using Turing; println(pathof(Turing))"`)
    turing_jl |> dirname |> dirname
end

function result_dir(name)
    project_dir = (@__DIR__) |> dirname
    results_dir = joinpath(project_dir, "benchmark_results")
    isdir(results_dir) || mkdir(results_dir)
    cd(results_dir) do
        isdir(name) || mkdir(name)
    end
    return joinpath(results_dir, name)
end

function local_benchmark(name, branch_names, turing_path=turingpath())
    @assert length(branch_names) > 1
    gitbranches(turing_path, branch_names)
    result_path = result_dir(name)
    shas = getbranchshas(turing_path, branch_names)

    cd(result_path) do
        for (branch, sha) in zip(branch_names, shas)
            onbranch(turing_path, branch) do
                for (root, dirs, files) in walkdir(BENCH_DIR)
                    for file in files
                        if should_run_benchmark(file)
                            filepath = abspath(joinpath(root, file))
                            println("BM: " * filepath)
                            # benchmark_files([filepath], send=false, save_path=snipsha(sha))
                        end
                    end
                end
            end
        end
        Reporter.write_report!("report.md", branches, shas)
    end

    return joinpath(result_path, "report.md")
end

end
