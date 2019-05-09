module Utils

using Dates
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
    # bm
    benchmark_branches,
    bm_name,
    # template
    code_bm_run

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
    cd(repopath) do
        currentbranch = gitcurrentbranch()
        currentbranch != branch && run(`git checkout $branch`)
        f()
        currentbranch != branch && run(`git checkout $currentbranch`)
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
Pkg.activate("{{{ :project_dir}}}");
Pkg.instantiate()

using CmdStan, Turing, TuringBenchmarks;
CmdStan.set_cmdstan_home!(TuringBenchmarks.CMDSTAN_HOME);
TuringBenchmarks.SEND_SUMMARY[] = {{{ :send }}}

include("{{{ :bm_file }}}");

using JSON;
log_file = TuringBenchmarks.Utils.result_filename(logd) * ".json"
cd(()->write(log_file, JSON.json(logd, 2)), "{{{ :save_path }}}")
"""
code_bm_run(data) = render(tmpl_code_bm_run, data)


end
