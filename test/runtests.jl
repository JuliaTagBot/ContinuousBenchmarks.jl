using Pkg

using ContinuousBenchmarks
using ContinuousBenchmarks.Runner

project_root = (@__DIR__) |> dirname
set_project_path(project_root)

for bm_file in get_benchmark_files()
    Runner.run_benchmarks([bm_file], save_path="."; ignore_error=false)
end
