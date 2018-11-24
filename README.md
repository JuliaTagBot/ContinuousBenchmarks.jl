# TuringBenchmarks 

This package has some benchmarking scripts for Turing. All models used here can be found in the `models` folder, all data can be found in the `data` folder, and all benchmarking scripts are in the `benchmarks` folder. 

Some data is generated via simulations found in the `simulations` folder. This data is generated when the package is built. When the package is built, `cmdstan` is also downloaded and setup where the URL can be accessed using `TuringBenchmarks.CMDSTAN_HOME`.

## How to benchmark Turing locally?

To locally benchmark 2 Turing branches:

1. Make sure all the changes to the active Turing branch are committed (or they will be lost!).
2. To benchmark the `master` and `new_branch` branches, run:
```julia
using TuringBenchmarks.TuringBot

report_path = TuringBot.local_benchmark(("master", "new_branch"))
```
3. Open the .md report file at `report_path` to view benchmarking results. More details can be found in the subdirectory of each commit which are in the same path as the report.

## How to contribute to TuringBenchmarks?

There are a number of ways to contribute to `TuringBenchmarks`:
1. Fix broken benchmarks.
2. Activate the inactive benchmarks by logging their results and using `send_log` to send the results to `TuringBot`.
3. Fix and activate the Stan benchmarks, any file in [benchmarks directory](https://github.com/TuringLang/TuringBenchmarks/tree/master/benchmarks) with `stan` in its name.
4. Add new benchmarks.

Both the broken and inactive benchmark file names can be found in https://github.com/TuringLang/TuringBenchmarks/blob/master/test/benchmarks.jl. The actual files can be found in https://github.com/TuringLang/TuringBenchmarks/tree/master/benchmarks.

## Guidelines for new benchmarks

1. Every benchmark makes a `log` `Dict` object which as the following mandatory keys:
 - `"name"`,
 - `"engine"`, and
 - "turing", where `log["turing"]` must have the key `"elapsed"`.
2. The `name`-`engine` combination must be unique for every benchmark.
3. The `log` `Dict` must be sent using the `send_log` function to activate the benchmark, otherwise results are not saved.
4. Every benchmark file must be runnable in its own Julia session. Any files which need to be executed first should be included in the benchmark file.
5. Since each benchmark is run in its own Julia session, any warm up runs should be included in the benchmark file to avoid counting the compilation time.

# TuringBenchmarks.TuringBot

## Setup

1. Register on the ultrahook website to get an API key and username.
2. Download and install [Ruby](https://www.ruby-lang.org/en/downloads/). 
3. Download [RubyGems](https://rubygems.org/pages/download) and extract the folder rubygems-x.x.x.
4. In a command prompt, call `~/Rubyxx-xxx/bin/ruby rubygems-x.x.x/setup.rb`.
5. Run `~/Rubyx-xxx/bin/gem ultrahook`
6. Run `echo "api_key: API_KEY" > ~/.ultrahook`, replacing `API_KEY` with the unique key from step 1.
7. CD into `~/Rubyxx-xxx/lib/ruby/gems/x.x.x/gems/ultrahook-x.x.x`, and run `ultrahook github port_number`, replacing `port_number` with the port number you would like to listen to events on, e.g. 8000.
8. Add the following url to the webhook of the repository you want to listen on: `http://github.username.ultrahook.com` replacing `username` with the username you registered in step 1.
9. CD into your favorite working directory and run `git clone https://github.com/TuringLang/TuringBenchmarks`.
10. Get an authentication token from Github.
11. Open a Julia session and run:
```julia
] activate ./TuringBenchmarks
] instantiate
ENV["GITHUB_USERNAME"] = "username"
ENV["GITHUB_AUTH"] = "auth_token"
```
replacing `username` with your Github username, and `auth_token` with your unique access token. Make sure the token has commenting, push and pull request access.

12. In the same Julia session, run:
```julia
using TuringBenchmarks.TuringBot
TuringBot.listen(port)
```
where `port` is the port you used in step 6. It is taken to be 8000 by default.
