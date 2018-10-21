using TuringBenchmarks
using Test

broken_benchmarks = [# Errors
	                "dyes.run.jl",
                	"kid.run.jl",
                	"negative_binomial.run.jl",
	                "normal-mixture.run.jl",
                    "school8.run.jl",
                    "binomial.run.jl",
                    "sv.run.jl",
                    #"MoC.run.jl",
                    #"optimization.jl",
                    #"profile.jl",
                    # Freezes
                	"lda.run.jl"]


function tobenchmark(filename)
    if filename ∈ broken_benchmarks
        return false
    else
        return true
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
