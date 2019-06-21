using Pkg
Pkg.activate(splitdir(@__DIR__)[1])
Pkg.instantiate()

# run(`git clone https://github.com/TuringLang/Turing.jl.git ../Turing.jl`)
# try pkg"develop ../Turing.jl" catch end
# try pkg"develop ../Turing.jl" catch end

using TuringBenchmarks
using TuringBenchmarks.Runner
# Runner.local_benchmark("TEST", ("master", "master"))

for (root, dirs, files) in walkdir(TuringBenchmarks.BENCH_DIR)
    for file in files
        if TuringBenchmarks.should_run_benchmark(file)
            bm_file = abspath(joinpath(root, file))
            Runner.run_benchmarks([bm_file], save_path="."; ignore_error=false)
        end
    end
end
