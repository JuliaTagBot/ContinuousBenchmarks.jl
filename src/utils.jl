module Utils

using Dates
using JSON
using Mustache

using ..Config

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
    result_filename,
    result_dir,
    # bm
    benchmark_branches,
    bm_name,
    # template
    code_bm_run,
    stringify_log,
    generate_report


const report_repo = Config.get_config("github.report_repo")
const report_branch = Config.get_config("github.report_branch", "master")
const bot_user = Config.get_config("github.user")

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
    brname = drop2(branches[ind])
    if brname[1] == '('
        brname = snip7(githeadsha())
    end
    return brname
end
gitcurrentbranch(path) = cd(gitcurrentbranch, path)

function gitbranches(branches)
    currentbranch = gitcurrentbranch()
    all_branches = drop2.(readlines(`git branch -al`))
    run(`git fetch --all`)
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
    remote = Config.get_config("target.use_remote_branches", true)
    currentbranch = gitcurrentbranch(repopath)
    cd(repopath) do
        if remote
            run(`git fetch --all`)
            all_branches = drop2.(readlines(`git branch -al`))
            if "origin/$branch" in all_branches
                run(`git checkout origin/$branch`)
            else
                run(`git checkout $branch`)
            end
        else # local
            run(`git checkout $branch`)
        end
    end
    f()
    cd(repopath) do
        run(`git checkout $currentbranch`)
    end
end

gitbranchsha(branch) = strip(read(`git rev-parse $branch`, String))
gitbranchsha(path, branch) = cd(()-> gitbranchsha(branch), path)
gitbranchshas(path, branches) = gitbranchsha.((path,), branches)

# path utils

project_root = (@__DIR__) |> dirname

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

bm_file_content(user, issue_url, comment_url, branches) = """
[trigger]
issue_url = "$(issue_url)"
comment_url = "$(comment_url)"
user = "$(user)"

[benchmark]
branches = $(repr(branches))
"""

bm_pr_content(comment_url) = """
This Pull Request is created for tracking the benchmark job.

See more information at $comment_url.
"""

bm_reply0_content(user, pr_url) = """
Hi @$user, a new benchmark job will be dispatched soon at your command,
you can track it here: $(pr_url).
"""

const tmpl_bm_pr_report_content = """
The benchmark job is finished.

The report is committed in this commit: {{{ :commit_id }}}.

You can see the report at {{{ :report_url }}}.

And below is the log reported from the benchmark:

{{#:report_logs}}

{{.}}

{{/:report_logs}}

If it has no issues, please consider to merge or close this PullRequest.
"""
function bm_pr_report_content(bm_name, commit_id, report_url)
    report_logs = get_benchmark_log(bm_name)
    render(tmpl_bm_pr_report_content,
           Dict(:commit_id => commit_id,
                :report_url => report_url,
                :report_logs => report_logs))
end

const tmpl_bm_commit_report_content = """
The benchmark job for this commit is finished.

The report is committed in this commit: {{{ :report_repo }}}#{{{ :commit_id }}}.

You can see the report at {{{ :report_url }}}.

Below is the log reported from the benchmark:

{{#:report_logs}}

{{.}}

{{/:report_logs}}
"""
function bm_commit_report_content(bm_name, commit_id, report_url)
    report_logs = get_benchmark_log(bm_name)
    render(tmpl_bm_commit_report_content,
           Dict(:report_repo => report_repo,
                :commit_id => commit_id,
                :report_url => report_url,
                :report_logs => report_logs))
end

bm_pr_error_content(exc) = """
An error occurred while running the benchmark:

  $exc

Please consider to fix it and trigger another one.
"""

bm_reply1_content(bm_name, user, repo, commit_id, report_url) = """
Hi @$user,

The benchmark [$bm_name] job is finished.

The report is committed in this commit: $repo@$commit_id.

You can see the report at $report_url  or go to the tracking PR to see it.
"""

bm_reply2_content(bm_name, user, repo, exc) = """
Hi @$user,

I am sorry that an error has occurred while running the benchmark [$bm_name]:

  $exc

Please consider to fix it and trigger another one.
"""


# code templates
const tmpl_code_bm_run = """
using TuringBenchmarks;
using TuringBenchmarks.Reporter;
using TuringBenchmarks.JSON;

include("{{{ :bm_file }}}");
result_file = TuringBenchmarks.Utils.result_filename(LOG_DATA) * ".json"
cd(() -> write(result_file, JSON.json(LOG_DATA, 2)), "{{{ :save_path }}}")
log_file = TuringBenchmarks.Utils.result_filename(LOG_DATA) * ".log"
Reporter.log_save(log_file, "{{{ :save_path }}}")
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
{{#turing_strings}}
| {{.}}
{{/turing_strings}}
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
        data["turing_strings"] = []
        if isa(logd["turing"], String)
            push!(data["turing_strings"], logd["turing"])
        else
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
    result_files = filter(result_files) do fname endswith(fname, ".json") end
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


function get_benchmark_log(bm_name)
    result_path = result_dir(bm_name)
    result_dirs = map(result_path |> readdir) do x joinpath(result_path, x) end
    result_dirs = filter(result_dirs) do x isdir(x) end
    logs = Vector{String}()
    for dir in result_dirs
        log_files = filter(dir |> readdir) do fname endswith(fname, ".log") end
        for fname in log_files
            log_file = joinpath(dir, fname)
            push!(logs, "===[ $(fname[1:end-4]) ]===")
            push!(logs, readlines(open(log_file))...)
        end
    end
    return logs
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
