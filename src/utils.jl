module Utils

using Dates

export
    benchmark_branches,
    bm_name

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

end
