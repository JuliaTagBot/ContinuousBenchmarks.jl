# TuringBenchmarks

This package has some benchmarking scripts for Turing. All models used
here can be found in the `models` folder, all data can be found in the
`data` folder, and all benchmarking scripts are in the `benchmarks`
folder.

Some data is generated via simulations found in the `simulations`
folder. This data is generated when the package is built. When the
package is built, `cmdstan` is also downloaded and setup where the URL
can be accessed using `TuringBenchmarks.CMDSTAN_HOME`.

## How to use the App:

- Install the app to your
  repository:
  [![install](https://img.shields.io/badge/-install%20app-blue.svg)](https://github.com/apps/turingbenchbot/installations/new);
- Add @TuringBenchBot as a collaborator if your repo is private;
- `@` the bot in an issue comment with the body like `bm("branch1",
  "branch2", "...")` to fire a benchmark job:
  - At leaset one branch should be given, if only one is given, e.g.,
    `bm("br1")`, the branch will be compared to the master branch;
  - If more than one branches are given and the master branch is one
    of them, e.g., `bm("master", "br1", "br2")`, the non-master
    branches will be compared to the master branch;
  - If more than one branches are given and the master branch is
    **NOT** one of them, e.g., `bm("br1", "br2", "br4")`, the first
    branch (`br1` here) will be used as the base branch and the other
    branches will be compared to it.

## The Bot and the App

- There are a TuringBenchBot GitHub Account
  (https://github.com/TuringBenchBot) and a TuringBenchBot GitHub App
  (https://github.com/apps/turingbenchbot);
- When you want to do a benchmark, `@` the GitHub Account in a comment,
  tell it the target branches, e.g. `@TuringBenchBot bm("master",
  "branch1")`, the app will receive the instruction;
- After receiving the benchmark instruction,
  - The app will create a new pull request in this repository
    (TuringBenchmarks) with information of the benchmark request to
    track the job. Then a benchmark job on the App server or on Travis
    CI will be triggered;
  - A comment reply to the issue where you `@` the bot will also be
    filed to tell you that a benchemark job will be run on Travis CI;
- When the benchemark job is done, The App server or the Travis CI
  server will commit the report to this repository on the branch of
  the tracking PR. A reply will also be make at where you trigger the
  bot. You can merge or close the tracking PR at this point freely.


## How to benchmark Turing locally?

To locally benchmark some Turing branches:

1. Make sure all the changes to the active Turing branch are committed
   (or they will be lost!).
2. To benchmark the `master` and `new_branch` branches, run:

```julia
using TuringBenchmarks.Runner;
report_path = Runner.local_benchmark("TEST", ("master", "new_branch"))
```

3. Open the `report.md` report file at `report_path` to view
   benchmarking results. More details can be found in the subdirectory
   of each commit which are in the same path as the report.

## How to contribute to TuringBenchmarks?

There are a number of ways to contribute to `TuringBenchmarks`:
1. Fix broken benchmarks.
2. Fix and activate the Stan benchmarks, any file
   in
   [benchmarks directory](https://github.com/TuringLang/TuringBenchmarks/tree/master/benchmarks) with
   `stan` in its name.
3. Add new benchmarks.

Both the broken and inactive benchmark file names can be
found
[here](https://github.com/TuringLang/TuringBenchmarks/blob/94eb4ba3740bf7b025a41947a37c5df93785a72c/src/TuringBenchmarks.jl#L20),
while the actual files can be
found
[here](https://github.com/TuringLang/TuringBenchmarks/tree/master/benchmarks).

## Guidelines for new benchmarks

1. Every benchmark makes a `log` `Dict` object which as the following mandatory keys:
 - `"name"`,
 - `"engine"`, and
 - "turing", where `log["turing"]` must have the key `"elapsed"`.
2. The `name`-`engine` combination must be unique for every benchmark.
3. The `log` `Dict` must be sent using the `send_log` function to
   activate the benchmark, otherwise results are not saved.
4. Every benchmark file must be runnable in its own Julia session. Any
   files which need to be executed first should be included in the
   benchmark file.
5. Since each benchmark is run in its own Julia session, any warm up
   runs should be included in the benchmark file to avoid counting the
   compilation time.
