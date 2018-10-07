using TuringBenchmarks
using Test

files_to_bench = ["binormal.run.jl"]

function tobenchmark(filename)
    if filename ∈ files_to_bench
        return true
    else
        return false
    end
end

TURING_HOME = joinpath(@__DIR__, "..")
for (root, dirs, files) in walkdir(TuringBenchmarks.BENCH_DIR)
    for file in files
        if tobenchmark(file) && splitext(file)[2] == ".jl"
            filepath = abspath(joinpath(root, file))
            benchmark_files([filepath], send=false)
            @test true
        end
    end
end
