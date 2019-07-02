# TuringBenchmarks

Orignally, this package has some benchmarking scripts for Turing. Now,
it evolves into a generic benchmarking library for Julia packages.

It can run in two modes:

1. Running as a GitHub App
2. Running on Travis-CI

## Configuration

TuringBenchmarks uses a `toml` file as its configuration file, there's
a template at `config/app.toml.tmpl`.

To run it, we need a GitHub Account, which will be used as the bot,
and a repository for storing the benchmark report.

If you want it to run as a GitHub App, a GitHub App should also be set
up, an its information, like app id, pem, etc., should be put into the
configuration file as well.

If you only want to run it on Travis-CI, just fork this repository,
and update the `config/app.travis.toml` file.

## Run as a GitHub App

Here how we run a GitHub App for Turing.jl:

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

#### The Bot and the App

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

## Run on Travis-CI

## How to benchmark Turing locally?

To locally benchmark some branches of your repository:

1. Make sure all the changes to the active branch are committed (or
   they will be lost!).
2. To benchmark the `master` and `new_branch` branches, run:

```julia
using TuringBenchmarks
using TuringBenchmarks.Runner;
TuringBenchmarks.set_project_path(".")
report_path = Runner.local_benchmark("TEST", ("master", "new_branch"))
```

3. Open the `report.md` report file at `report_path` to view
   benchmarking results. More details can be found in the subdirectory
   of each commit which are in the same path as the report.
