using TuringBenchmarks
using Test

TURING_HOME = joinpath(@__DIR__, "..")
for (root, dirs, files) in walkdir(TuringBenchmarks.BENCH_DIR)
    for file in files
        if splitext(file)[2] == ".jl"
            filepath = joinpath(root, file)
            println("Testing `$model` ... ")
            job = `julia -e " cd(\"$(pwd())\"); 
                                CMDSTAN_HOME = \"$CMDSTAN_HOME\";
                                using Turing, TuringBenchmarks;
                                TuringBenchmarks.SEND_SUMMARY[] = false;
                                include(TuringBenchmarks.BENCH_DIR*\"/$(model).run.jl\")"`
            println(job); run(job)
            println("`$model` ✓")
            @test true
        end
    end
end
