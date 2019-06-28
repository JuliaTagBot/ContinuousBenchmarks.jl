using Pkg
project_root = (@__DIR__) |> dirname
Pkg.activate()
Pkg.instantiate()
Pkg.resovle()

# run(`git clone https://github.com/TuringLang/Turing.jl.git ../Turing.jl`)
# try pkg"develop ../Turing.jl" catch end
# try pkg"develop ../Turing.jl" catch end

using TuringBenchmarks
using TuringBenchmarks.Runner

set_project_path(project_root)

for bm_file in get_benchmark_files()
    Runner.run_benchmarks([bm_file], save_path="."; ignore_error=false)
end
