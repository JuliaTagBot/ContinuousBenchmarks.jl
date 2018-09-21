run(`wget https://github.com/stan-dev/cmdstan/releases/download/v2.14.0/cmdstan-2.14.0.zip`)
run(`unzip -qq cmdstan-2.14.0.zip`)
CMDSTAN_HOME = pwd() * "/cmdstan-2.14.0"
println("CMDStan is installed at path: $CMDSTAN_HOME")
Pkg.add("Stan")
Pkg.add("UnicodePlots")
Pkg.add("HDF5")
Pkg.add("JLD2")
Pkg.add("Requests")
Pkg.add("Stats")
Pkg.add("StatsFuns")
Pkg.add("Turing")
Pkg.add("TuringBenchmarks")

using TuringBenchmarks

for (root, dirs, files) in walkdir(TuringBenchmarks.SIMULATIONS_DIR)
    for file in files
        if splitext(file)[2] == ".jl"
            filepath = joinpath(root, file)
            println("Running: ", filepath)
            include(filepath)
        end
    end
end
