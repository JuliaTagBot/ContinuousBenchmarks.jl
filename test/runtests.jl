using TuringBenchmarks
using Test

filenames_to_test = ["bernoulli.run.jl"]

TURING_HOME = joinpath(@__DIR__, "..")
for (root, dirs, files) in walkdir(TuringBenchmarks.BENCH_DIR)
    for file in files
        if file ∈ filenames_to_test && splitext(file)[2] == ".jl"
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
