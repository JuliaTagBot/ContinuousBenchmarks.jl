#using Pkg, TuringBenchmarks

# Download and uncompress cmdstan
#if !haskey(ENV, "CMDSTAN_HOME") || ENV["CMDSTAN_HOME"] == ""
#    project_root = (@__DIR__) |> dirname
#    cmdstan_home = abspath(joinpath(project_root, "cmdstan"))
#    # Get cmdstan and uncompress it from its url in deps/cmdstan_url.txt
#    ispath(cmdstan_home) || cd(project_root) do
#        run(`git clone https://github.com/stan-dev/cmdstan --recursive`)
#    end
#    cd(cmdstan_home) do
#        run(`git fetch --all`)
#        v = read(`git describe --tags`, String)
#        run(`git checkout $(strip(v))`)
#    end
#    @info("CMDStan is installed at path: $cmdstan_home")
#end
#
#Pkg.add(["FileIO", "JLD2"])
#
## Generate data from simulations
#const SIMULATIONS_DIR = abspath(joinpath(@__DIR__, "..", "simulations"))
#for (root, dirs, files) in walkdir(SIMULATIONS_DIR)
#    for file in files
#        if splitext(file)[2] == ".jl"
#            filepath = joinpath(root, file)
#            println("Running: $filepath")
#            include(filepath)
#        end
#    end
#end
