module Utils

using Dates
using JSON
using Mustache

using ..TuringBenchmarks: BENCH_DIR

export
    # string
    snip,
    snip7,
    drop2,
    # git
    githeadsha,
    gitcurrentbranch,
    gitbranches,
    onbranch,
    gitbranchsha,
    gitbranchshas,
    # path
    turingpath,
    find_bm_file,
    result_filename,
    result_dir,
    # bm
    benchmark_branches,
    bm_name,
    # template
    code_bm_run,
    stringify_log,
    generate_report

# string utils

snip(str, len) = str[1:min(len, end)]
snip7(sha) = snip(sha, 7)
drop2(x) = x[3:end]


# git utils

githeadsha() = strip(read(`git rev-parse HEAD`, String))
githeadsha(path) = cd(githeadsha, path)

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
    currentbranch = gitcurrentbranch(repopath)
    currentbranch != branch && cd(repopath) do
        run(`git fetch -all`)
        run(`git checkout hard origin/$branch`)
        # run(`git checkout $branch`) # local
    end
    f()
    currentbranch != branch && cd(repopath) do
        run(`git checkout $currentbranch`)
    end
end

gitbranchsha(branch) = strip(read(`git rev-parse $branch`, String))
gitbranchsha(path, branch) = cd(()-> gitbranchsha(branch), path)
gitbranchshas(path, branches) = gitbranchsha.((path,), branches)

# path utils

function turingpath()
    juliaexe_path = joinpath(Sys.BINDIR, Base.julia_exename())
    turing_jl = readchomp(`$(juliaexe_path) -e "using Turing; println(pathof(Turing))"`)
    turing_jl |> dirname |> dirname
end

function find_bm_file(name_or_path)
    name_or_path = replace(name_or_path, "\\"=>"\\\\")
    occursin("/", name_or_path) && return name_or_path
    endswith(name_or_path, ".jl") && return name_or_path
    joinpath(BENCH_DIR, "$(name_or_path).run.jl")
end

function result_filename(data)
    filename = join([data["name"], data["engine"]], "_")
    filename = replace(filename, [' ', ',', '('] => "_")
    filename = replace(filename, [')', '.', ':'] => "")
    filename
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

# benchmark utils
function nonmaster_br(brches::Vector{String})
    for br in sort(brches)
        br != "master" && return br
    end
    return "none"
end

function benchmark_branches(brches::Vector{String})
    "master" in brches ? brches : ["master", brches...]
end


function benchmark_branches(text::String)
    reg = r".*bm\((.+)\)"
    m = match(reg, text)
    m == nothing && return []
    brs = map(split(m[1], ",")) do x convert(String, strip(x, [' ', '"'])) end
    return benchmark_branches(brs)
end

bm_name(branch::String) = "BM-" * Dates.format(now(), "YYYYmmddHHMM-") * branch
bm_name(brches::Vector{String}) = bm_name(nonmaster_br(brches))

bm_file_content(issue_url, comment_url, branches) = """
[trigger]
issue_url = "$(issue_url)"
comment_url = "$(comment_url)"

[benchmark]
branches = $(repr(branches))
"""

bm_issue_content(commit_id, comment_url) = """
A new commit is summited to trigger a benchmark job: $commit_id.

The issue is created for tracking the benchmark job.

See more information at $comment_url.
"""

bm_reply0_content(issue_url) = """
Hi Sir, a new benchmark job will be dispatched soon at your command,
you can track it here: $(issue_url).
"""

bm_issue_close_content(commit_id, report_url) = """
The benchmark job is finished.

The report is committed in this commit: $commit_id.

You can see the report at $report_url.
"""

bm_reply1_content(bm_name, repo, commit_id, report_url) = """
Hi Sir,

The benchmark [$bm_name] job is finished.

The report is committed in this commit: $repo@$commit_id.

You can see the report at $report_url.
"""

# code templates
const tmpl_code_bm_run = """
using Pkg;

Pkg.activate("{{{ :project_dir }}}");
Pkg.instantiate()

Pkg.develop(PackageSpec(path="{{{ :project_dir }}}/../Turing.jl"))

using CmdStan, Turing, TuringBenchmarks;
CmdStan.set_cmdstan_home!(TuringBenchmarks.CMDSTAN_HOME);

include("{{{ :bm_file }}}");

using JSON;
log_file = TuringBenchmarks.Utils.result_filename(logd) * ".json"
cd(()->write(log_file, JSON.json(logd, 2)), "{{{ :save_path }}}")
"""
code_bm_run(data) = render(tmpl_code_bm_run, data)

# report template

const tmpl_log_string = """
/=======================================================================
| Benchmark Result for >>> {{{ name }}} <<<
|-----------------------------------------------------------------------
| Overview
|-----------------------------------------------------------------------
| Inference Engine  : {{{ engine }}}
| Time Used (s)     : {{{ time }}}
{{#time_stan}}
|   -> time by Stan : {{{ time_stan }}}
{{/time_stan}}
| Mem Alloc (bytes) : {{{ mem }}}
{{#turing}}
|-----------------------------------------------------------------------
| Turing Inference Result
|-----------------------------------------------------------------------
{{/turing}}
{{#turing_items}}
| >> {{{ name }}} <<
| mean = {{{ mean }}}
{{#analytic}}
|   -> analytic = {{{ analytic }}}
{{/analytic}}
{{#anal_diff}}
|        |--*-->  diff = {{{ anal_diff }}}
{{/anal_diff}}
{{#stan}}
|   -> Stan     = {{{ stan }}}
{{/stan}}
{{#stan_diff}}
|        |--*--> diff = {{{ anal_diff }}}
{{/stan_diff}}
{{/turing_items}}
{{#note}}
|-----------------------------------------------------------------------
| Note:
|   {{{ note }}}
{{/note}}
\\=======================================================================
"""

function stringify_log(logd::Dict, monitor=[])
    data = Dict{Any, Any}(
        "name" => logd["name"],
        "engine" => logd["engine"],
        "time" => logd["time"],
        "mem" => logd["mem"],
    )
    haskey(logd, "time_stan") && (data["time_stan"] = logd["time_stan"])
    haskey(logd, "note") && (data["note"] = logd["note"])

    if haskey(logd, "turing")
        data["turing"] = true
        data["turing_items"] = []
        for (v, m) = logd["turing"]
            (!isempty(monitor) && !(v in monitor)) && continue

            item = Dict{Any, Any}("name" => v)
            item["mean"] = round.(m, digits=3)
            if haskey(logd, "analytic") && haskey(logd["analytic"], v)
                item["analytic"] = round(logd["analytic"][v], digits=3)
                diff = abs.(m - logd["analytic"][v])
                if sum(diff) > 0.2
                    item["anal_diff"] = round(diff, digits=3)
                end
            end
            if haskey(logd, "stan") && haskey(logd["stan"], v)
                item["stan"] = round.(logd["stan"][v], digits=3)
                diff = abs.(m - logd["stan"][v])
                if sum(diff) > 0.2
                    item["stan_diff"] = round.(diff, digits=3)
                end
            end
            push!(data["turing_items"], item)
        end
    end

    render(tmpl_log_string, data)
end

const tmpl_report_md = """
# Benchmark Report

## Job properties

**Turing Branches**:
{{#branches}}
- **{{{ name }}}**({{ sha }}) {{#is_base}}**[BASE_BRANCH]**{{/is_base}}
{{/branches}}

**TuringBenchmarks Commit**: {{ bench_commit }}

## Results Table:

Below is a table of this job's results, obtained by running the
benchmarks found in
[TuringLang/TuringBenchmarks](https://github.com/TuringLang/TuringBenchmarks). The
table shows the time ratio of the N (N >= 2) Turing commits
benchmarked. A ratio greater than `1.0` denotes a possible regression
(marked with :-1:), while a ratio less than `1.0` denotes a possible
improvement (marked with :+1:). Results are subject to
noise so small fluctuations around `1.0` may be ignored.

| BenchMark    | {{#branches}} TimeRatio({{{ name }}}) | {{/branches}}
| -----------  | {{#branches}} ----------------------- | {{/branches}}
{{#benchmarks}}
| {{{ name }}} | {{#results}} {{{ label }}} | {{/results}}
{{/benchmarks}}

## Raw Results:

{{#benchmarks}}
### {{{ name }}}
{{#results}}
#### On Branch `{{{ branch }}`
```javascript
{{{ result_json }}}
```

{{/results}}
{{/benchmarks}}

"""

function generate_report(bm_name, branches, shas, base_branch = "")
    result_path = result_dir(bm_name)
    if !(base_branch in branches)
        base_branch = ("master" in branches) ? "master" : branches[1]
    end

    data = Dict{Any, Any}(
        "branches" => [],
        "benchmarks" => [],
    )

    for (br, sha) in zip(branches, shas)
        item = Dict{Any, Any}(
            "name" => br,
            "sha" => snip7(sha),
            "is_base" => br == base_branch,
        )
        push!(data["branches"], item)
    end

    result_files = readdir(joinpath(result_path, snip7(shas[1])))
    result_files = filter(result_files) do fname
        all(isfile, map((sha) -> joinpath(result_path, snip7(sha), fname), shas))
    end

    for fname in result_files
        base_br_idx = indexin(branches, [base_branch])[1]
        base_sha = snip7(shas[base_br_idx])
        base_result_file = joinpath(result_path, base_sha, fname)
        base_result_json = read(open(base_result_file), String)
        base_result_data = JSON.parse(base_result_json)
        base_time = round(base_result_data["time"] * 1000, digits = 3)
        if haskey(base_result_data, "bench_commit")
            data["bench_commit"] = base_result_data["bench_commit"] |> snip7
        end

        bench = Dict{Any, Any}(
            "name" => """`$(base_result_data["name"]) - $(base_result_data["engine"])`""",
            "results" => [],
        )

        for (br, sha) in zip(branches, shas)
            result_file = joinpath(result_path, snip7(sha), fname)
            result_json = read(open(result_file), String)
            result_data = JSON.parse(result_json)
            time = round(result_data["time"] * 1000, digits = 3)
            ratio = round(time / base_time, digits=2)
            symbol = ratio > 1 ? ":-1:" : ":+1:"
            item = Dict{Any, Any}(
                "branch" => br,
                "result_json" => result_json,
                "label" => "$ratio ($time ms / $base_time ms) $symbol",
            )

            push!(bench["results"], item)
        end

        push!(data["benchmarks"], bench)
    end

    render(tmpl_report_md, data)
end

# legacy
# Get running time of Stan
function get_stan_time(stan_model_name::String)
    s = readlines(pwd() * "/tmp/$(stan_model_name)_samples_1.csv")
    println(s[end - 1])
    m = match(r"(?<time>[0-9]+.[0-9]*)", s[end - 1])
    parse(Float64, m[:time])
end

end
