using Test
using TuringBenchmarks: BENCH_DIR, inactive_benchmarks, tobenchmark, benchmark_files

function runbenchmarks(; send=false)
    for (root, dirs, files) in walkdir(BENCH_DIR)
        for file in files
            if tobenchmark(file) && !(send && file ∈ inactive_benchmarks) && splitext(file)[2] == ".jl"
                filepath = abspath(joinpath(root, file))
                benchmark_files([filepath], send=send)
                @test true
            end
        end
    end
end
