# ContinuousBenchmarks

This package evolved from Turing.jl specific benchmarking tools to a
generic benchmarking library for continuous benchmarking.

It can be used in the following scenarios:

1. Running on Travis-CI
2. Running locally
3. Running as a GitHub App on a dedicated server

## How it works

### Writing benchmarks

ContinuousBenchmarks doesn't offer tools to measure metrics of
interests, so to benchmark your code, you should resort tools like the
Julia built-in macros for benchmarks, like `@timev`, `@timed`,
`@elapsed`, and `@allocated`, or the package `BenchmarkTools.jl`.

We use a simple protocol to collect measured metrics from the
benchmarks: storing the measured metrics in a global variable named
`LOG_DATA` which is either a `Dict{String, Any}` or a `DataFrame`, for
example:

```julia
# file: benchmark1.jl
val, t, bytes, gctime, memallocs = @timed rand(10^6)
LOG_DATA = Dict("time" => t, "memory" => bytes, "gctime" => gctime)

# or
# LOG_DATA = DataFrame(time=[t], memory=[bytes], gctime=[gctime])
```

Each benchmark runs in its own Julia process, so each benchmark has
its own `LOG_DATA` variable, though it is global.

You can report more than one record using the `DataFrame` type.  Note
that all records reported during continuous benchmarking should report
using the metrics as Dict keys and DataFrame colums are shared.

### Configure the benchmarks project

After the benchmarks are written, we should give a config file. Here
is an example:

```
CONFIG = Dict(
    "target.project_dir" => (@__DIR__) |> dirname |> abspath,
    "reporter.use_dataframe" => true,
)

BENCHMARK_FILES = [
    "benchmark1.jl",
]

CONFIG["benchmark_files"] = map(BENCHMARK_FILES) do x joinpath(@__DIR__, x) end

```

As you see, we use a global variable `CONFIG::Dict` to hold the
configuration items:

- `target.project_dir` is the path of the project which we want to
  benchmark, the benchmarks will run in a Julia process started by
  `julia --project=<target.project_dir>`.
- `benchmark_files` is a list whose elements are the absolute path of
  the benchmark files.

### Run benchmarks on Travis-CI

When the benchmarks and the config file are ready, we can write a
script to run them on Travis, and here is an example:
https://github.com/TuringLang/Turing.jl/blob/master/benchmarks/runbenchmarks.jl
.

When someone pushes new commits to the repository, the script will run
on Travis. In the script, we install all the dependencies of the
target package, install the package `ContinuousBenchmarks.jl`, then
check the current branch(or commit) which is just updated. Then we run
the below Julia code on the updated branch and the master branch
separately:

```
using ContinuousBenchmarks
using ContinuousBenchmarks.Runner
ContinuousBenchmarks.set_benchmark_config_file("/path/to/config.jl")
Runner.run_bm_on_travis("$BM_JOB_NAME", ("$BASE_BRANCH", "$CURRENT_BRANCH"), "$COMMIT_SHA")
```

After it completes, all the measured metrics will be collected, then a
benchmark report will be generated in markdown format, the report will
be committed into a repository on GitHub(you can specify which one to
use in the config file).

### Run locally

To locally benchmark some branches of your repository:

1. Make sure all the changes to the active branch are committed (or
   they will be lost!).
2. To benchmark the `master` and `new_branch` branches, run:

```julia
using ContinuousBenchmarks
using ContinuousBenchmarks.Runner;
report_path = Runner.local_benchmark("TEST", ("master", "new_branch"))
```

3. Open the `report.md` report file at `report_path` to view
   benchmarking results. More details can be found in the sub
   directory of each commit which are in the same path as the report.

### Run as a GitHub App

In order to run ContinuousBenchmarks as a GitHub, you need some
preparation:

- Register a GitHub App
- Set up a dedicated server to run the app

Then we put the GitHub information in the config file and start the
app server:

```
export TBB_CONFIG=/path/to/config/file # TOML one
julia -e 'using ContinuousBenchmarks; ContinuousBenchmarks.AppServer.main()'
```

Here we use the Github App for Turing.jl as an example:

- Install the app to your
  repository:
  [![install](https://img.shields.io/badge/-install%20app-blue.svg)](https://github.com/apps/turingbenchbot/installations/new);
- Add @BayesianBot as a collaborator if your repo is private;
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

#### The Bot and the App

- There are a BayesianBot GitHub Account
  (https://github.com/BayesianBot) and a TuringBenchBot GitHub App
  (https://github.com/apps/turingbenchbot);
- When you want to do a benchmark, `@` the GitHub Account in a comment,
  tell it the target branches, e.g. `@BayesianBot bm("master",
  "branch1")`, the app will receive the instruction;
- After receiving the benchmark instruction,
  - The app will create a new pull request in this repository
    (ContinuousBenchmarks) with information of the benchmark request to
    track the job. Then a benchmark job on the App server or on Travis
    CI will be triggered;
  - A comment reply to the issue where you `@` the bot will also be
    filed to tell you that a benchemark job will be run on Travis CI;
- When the benchemark job is done, The App server or the Travis CI
  server will commit the report to this repository on the branch of
  the tracking PR. A reply will also be make at where you trigger the
  bot. You can merge or close the tracking PR at this point freely.

## More about configuration

ContinuousBenchmarks uses a `toml` file as its default configuration
file, there's a template at `config/app.toml.tmpl`.

When the benchmark job starts, the `toml` config file according to the
ENV variable `TBB_CONFIG` will be loaded first, then, if we call
`ContinuousBenchmarks.set_benchmark_config_file("some_config.jl")` in
our travis script or somewhere, the config file specified by the
argument will be loaded. For example, we run benchmarks for Turing.jl
on Travis:

- The ENV variable "TBB_CONFIG" is "config/app.travis.toml"
- We call
  `ContinuousBenchmarks.set_benchmark_config_file(joinpath("$PROJECT_DIR",
  "benchmarks/benchmark_config.jl"))` in
  https://github.com/TuringLang/Turing.jl/blob/master/benchmarks/runbenchmarks.jl

In this situation, `config/app.travis.toml` will be loaded first, and
"benchmarks/benchmark\_config.jl" will be loaded after that.  So you
can overwrite the configurations in the `toml` file by setting the
same items in "benchmarks/benchmark\_config.jl", more precisely, the
`CONFIG` variable in that file.
