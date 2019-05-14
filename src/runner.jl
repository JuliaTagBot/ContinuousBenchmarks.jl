module Runner

using Pkg
using GitHub
using Base64

using ..Utils
using ..Reporter
using ..Config

using ..TuringBenchmarks: BENCH_DIR, default_model_list, should_run_benchmark

const app_repo = Config.get_config("github.app_repo")

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
    params = Dict("ref" => name) # on the PR branch
    bm_file_content = GitHub.file(app_repo, "jobs/$(name).toml"; params=params, auth=bot_auth)
    content = String(base64decode(replace(bm_file_content.content, "\n" =>"")))
    bm_info = Pkg.TOML.parse(content)
    report_path = local_benchmark(name, bm_info["benchmark"]["branches"])
    Reporter.send(name, bm_info, report_path)
end

function local_benchmark(name, branch_names, turing_path=turingpath())
    @assert length(branch_names) > 1
    branch_names = [branch_names...]
    gitbranches(turing_path, branch_names)
    result_path = result_dir(name)
    shas = gitbranchshas(turing_path, branch_names)

    cd(result_path) do
        for (branch, sha) in zip(branch_names, shas)
            onbranch(turing_path, branch) do
                isdir(snip7(sha)) || mkdir(snip7(sha))
                for (root, dirs, files) in walkdir(BENCH_DIR)
                    for file in files
                        if should_run_benchmark(file)
                            bm_file = abspath(joinpath(root, file))
                            run_benchmarks([bm_file], save_path=snip7(sha))
                        end
                    end
                end
            end
        end
        Reporter.write_report!(name, "report.md", branch_names, shas)
    end

    return joinpath(result_path, "report.md")
end

function run_benchmarks(files=default_model_list; ignore_error=true, save_path="")
    @info("Turing benchmarking started.")
    for file in files
        try
            run_benchmark(file, save_path=save_path)
        catch err
            @error("Error occurs while running the benchmark: $file.")
            if :msg in fieldnames(typeof(err))
                @error(err.msg)
            end
            !ignore_error && throw(err)
        end
    end
    @info("Turing benchmarking completed.")
end

function run_benchmark(fileormodel; save_path="")
    bm_path = find_bm_file(fileormodel)
    @info("Benchmarking `$bm_path` ... ")
    data = Dict(
        :project_dir => dirname(@__DIR__),
        :turing_path => turingpath(),
        :bm_file => bm_path,
        :save_path => save_path,
    )
    julia_path = joinpath(Sys.BINDIR, Base.julia_exename())
    code = code_bm_run(data)
    job = `$julia_path -e $code`
    @debug(job);
    run(job)
    @info("`$bm_path` ✓")
    return
end

end
