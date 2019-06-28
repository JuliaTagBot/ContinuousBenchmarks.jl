module Runner

using Pkg
using GitHub
using Base64

using ..Utils
using ..Reporter
using ..Config

using ..TuringBenchmarks: get_benchmark_files, PROJECT_PATH

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
    report_path = nothing
    try
        report_path = local_benchmark(name, bm_info["benchmark"]["branches"])
    catch ex
        Reporter.send_error(name, bm_info, ex)
        return
    end
    Reporter.send(name, bm_info, report_path)
end

function local_benchmark(name, branch_names)
    @assert length(branch_names) > 1
    branch_names = [branch_names...]
    gitbranches(PROJECT_PATH[], branch_names)
    result_path = result_dir(name)
    shas = gitbranchshas(PROJECT_PATH[], branch_names)

    for (branch, sha) in zip(branch_names, shas)
        onbranch(PROJECT_PATH[], branch) do
            save_path = joinpath(result_path, snip7(sha))
            isdir(save_path) || mkdir(save_path)
            for bm_file in get_benchmark_files()
                run_benchmarks([bm_file], save_path=save_path)
            end
        end
    end
    report_path = joinpath(result_path, "report.md")
    Reporter.write_report!(name, report_path, branch_names, shas)
    return report_path
end

function run_benchmarks(files; ignore_error=true, save_path="")
    @info("Turing benchmarking started.")
    for file in files
        try
            run_benchmark(file, save_path=save_path)
        catch err
            @error("Error occurs while running the benchmark: $file.")
            if :msg in fieldnames(typeof(err))
                @error(err.msg)
            end
            !ignore_error && rethrow(err)
        end
    end
    @info("Turing benchmarking completed.")
end

function run_benchmark(bm_path; save_path="")
    @info("Benchmarking `$bm_path` ... ")
    data = Dict(
        :project_dir => dirname(@__DIR__),
        :project_path => PROJECT_PATH[],
        :bm_file => bm_path,
        :save_path => save_path,
    )
    julia_path = joinpath(Sys.BINDIR, Base.julia_exename())
    code = code_bm_run(data)
    job = `$julia_path --project=$(PROJECT_PATH[]) -e $code`
    @info(job);
    run(job)
    @info("`$bm_path` ✓")
    return
end

function run_bm_on_travis(name, branch_names, cid)
    report_path = local_benchmark(name, branch_names)
    Reporter.send_from_travis(name, cid, report_path)
end

end
