using TuringBenchmarks
using Test

mamba_benchmarks = ["binomial.run.jl", 
                    "dyes.run.jl", 
                    "gdemo-gewke.run.jl", 
                    "kid.run.jl", 
                    "school8.run.jl", 
                    "sv.run.jl"]

#files_to_bench = ["bernoulli.run.jl"]
files_to_bench = ["bernoulli.run.jl"]

function tobenchmark(filename)
    if filename ∈ mamba_benchmarks
        return false
    elseif filename ∈ files_to_bench
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
