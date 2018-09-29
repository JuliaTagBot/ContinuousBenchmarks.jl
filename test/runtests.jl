using TuringBenchmarks
using Test

function tobenchmark(filename)
    #filenames_to_bench = ["bernoulli.run.jl"]
    filenames_to_bench = ["bernoulli.run.jl"]
    if filename ∈ filenames_to_bench
        return true
    else
        return false
    end
end

mamba_benchmarks = ["binomial.run.jl", 
                    "dyes.run.jl", 
                    "gdemo-gewke.run.jl", 
                    "kid.run.jl", 
                    "school8.run.jl", 
                    "sv.run.jl"]

function nottobenchmark(filename)
    if filename ∈ mamba_benchmarks
        return false
    else
        return true
    end
end

TURING_HOME = joinpath(@__DIR__, "..")
for (root, dirs, files) in walkdir(TuringBenchmarks.BENCH_DIR)
    for file in files
        if tobenchmark(file) && !nottoenchmark(file) && splitext(file)[2] == ".jl"
            filepath = abspath(joinpath(root, file))
            println("Testing `$file` ... ")
            job = `julia -e " cd(\"$(replace(pwd(), "\\"=>"\\\\"))\"); 
                                CMDSTAN_HOME = \"$(replace(TuringBenchmarks.CMDSTAN_HOME, "\\"=>"\\\\"))\";
                                using Turing, TuringBenchmarks;
                                TuringBenchmarks.SEND_SUMMARY[] = false;
                                include(\"$(replace(filepath, "\\"=>"\\\\"))\")"`
            println(job); run(job)
            println("`$file` ✓")
            @test true
        end
    end
end
