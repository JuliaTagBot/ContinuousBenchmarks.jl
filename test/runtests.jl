using Pkg

using ContinuousBenchmarks
using ContinuousBenchmarks.Runner
using ContinuousBenchmarks.Config

project_root = (@__DIR__) |> dirname
Config.set_config("target.project_dir", project_root)

for bm_file in get_benchmark_files()
    Runner.run_benchmarks([bm_file], save_path="."; ignore_error=false)
end
