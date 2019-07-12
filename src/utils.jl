module Utils

using CSV
using DataFrames
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
    generate_report,
    generate_report_dataframe


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

function result_filename(filename)
    filename = replace(filename, [' ', ',', '('] => "_")
    filename = replace(filename, [')', '.', ':'] => "")
    filename
end
result_filename(data::Dict) = result_filename(data["name"] * "_" * data["engine"])
result_filename(data::DataFrame) = result_filename(data[:name][1])

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

```
{{#:report_logs}}
{{.}}
{{/:report_logs}}
```

If it has no issues, please consider to merge or close this PullRequest.
"""
function bm_pr_report_content(bm_name, commit_id, report_url)
    tmpl = Config.get_config(
        "comment_templates.app_bm_complete_for_pr",
        tmpl_bm_pr_report_content)
    report_logs = get_benchmark_log(bm_name)
    render(tmpl,
           Dict(:commit_id => commit_id,
                :report_url => report_url,
                :report_logs => report_logs))
end

const tmpl_bm_commit_report_content = """
The benchmark job for this commit is finished.

The report is committed in this commit: {{{ :report_repo }}}#{{{ :commit_id }}}.

You can see the report at {{{ :report_url }}}.

Below is the log reported from the benchmark:

```
{{#:report_logs}}
{{.}}
{{/:report_logs}}
```
"""
function bm_commit_report_content(bm_name, commit_id, report_url)
    tmpl = Config.get_config(
        "comment_templates.ci_bm_complete_for_commit",
        tmpl_bm_commit_report_content)
    report_logs = get_benchmark_log(bm_name)
    render(tmpl,
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
using ContinuousBenchmarks;
using ContinuousBenchmarks.Reporter;

{{#:config_file}}
ContinuousBenchmarks.set_benchmark_config_file("{{{ :config_file }}}")
{{/:config_file}}
include("{{{ :bm_file }}}");
Reporter.save_result(LOG_DATA, "{{{ :bm_file }}}", "{{{ :save_path }}}")
Reporter.save_log(LOG_DATA, "{{{ :save_path }}}")
"""
code_bm_run(data) = render(tmpl_code_bm_run, data)

# report template

const tmpl_report_md = """
# Benchmark Report

## Job properties

**Target Project Branches**:
{{#branches}}
- **{{{ name }}}**({{ sha }}) {{#is_base}}**[BASE_BRANCH]**{{/is_base}}
{{/branches}}

## Results Table:

Below is a table of this job's results. The table shows the time ratio
of the N (N >= 2) commits benchmarked. A ratio greater than `1.0`
denotes a possible regression (marked with :-1:), while a ratio less
than `1.0` denotes a possible improvement (marked with :+1:). Results
are subject to noise so small fluctuations around `1.0` may be
ignored.

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
        base_br_idx = indexin([base_branch], branches)[1]
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

const tmpl_report_md_dataframe = """
# Benchmark Report

## Job properties

**Target Project Branches**:
{{#branches}}
- **{{{ name }}}**({{ sha }}) {{#is_base}}**[BASE_BRANCH]**{{/is_base}}
{{/branches}}

## Results Table:

Below is a table of this job's results. The table shows the
performance indicators of the N (N >= 2) commits benchmarked.

| Row |{{#columns}} {{{ . }}} | {{/columns}}
| --- |{{#columns}} --------- | {{/columns}}
{{{ table_body }}}
"""

function generate_report_dataframe(bm_name, branches, shas, base_branch = "")
    result_path = result_dir(bm_name)
    if !(base_branch in branches)
        base_branch = ("master" in branches) ? "master" : branches[1]
    end

    data = Dict{Any, Any}(
        "branches" => [],
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
    result_files = filter(result_files) do fname endswith(fname, ".csv") end
    result_files = filter(result_files) do fname
        all(isfile, map((sha) -> joinpath(result_path, snip7(sha), fname), shas))
    end

    sha_col = Vector{String}()
    results = []

    for fname in result_files
        for sha in shas
            result_file = joinpath(result_path, snip7(sha), fname)
            result = CSV.read(result_file)
            push!(results, result)
            row_count = size(result)[1]
            push!(sha_col, repeat([sha], row_count)...)
        end
    end

    df_results = vcat(results...)
    df_branches = DataFrame(Branch=branches[indexin(sha_col, shas)], Commit=snip7.(sha_col))
    big_dataframe = hcat(df_branches, df_results)
    table_body = join(split(replace(string(big_dataframe), "│" => "|"), "\n")[5:end], "\n")
    data["table_body"] = table_body
    data["columns"] = names(big_dataframe)

    render(tmpl_report_md_dataframe, data)
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
