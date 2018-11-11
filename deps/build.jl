# Download and uncompress cmdstan
if !haskey(ENV, "CMDSTAN_HOME") || ENV["CMDSTAN_HOME"] == ""
    # Make the cmdstan home directory
    
    cmdstan_home = abspath(joinpath("..", "cmdstan"))
    # Get cmdstan and uncompress it from its url in deps/cmdstan_url.txt
    ispath(cmdstan_home) || cd("..") do
        run(`git clone https://github.com/stan-dev/cmdstan --recursive`)
    end
    cd(cmdstan_home) do
        run(`git fetch --all`)
        v = read(`git describe --tags`, String)
        run(`git checkout $(strip(v))`)
    end
    println("CMDStan is installed at path: $cmdstan_home")

    # Wrie the src file that sets ENV["CMDSTAN_HOME"]
    write(joinpath("..", "src", "cmdstan_home.jl"), "cmdstan_home() = \"$(replace(cmdstan_home, "\\"=>"\\\\"))\"")
else
    write(joinpath("..", "src", "cmdstan_home.jl"), "cmdstan_home() = $(ENV["CMDSTAN_HOME"])")
end

using Pkg, TuringBenchmarks
Pkg.add(["FileIO", "JLD2", "Turing"])

TuringBenchmarks.SEND_SUMMARY[] = false

# Generate data from simulations
for (root, dirs, files) in walkdir(TuringBenchmarks.SIMULATIONS_DIR)
    for file in files
        if splitext(file)[2] == ".jl"
            filepath = joinpath(root, file)
            println("Running: $filepath")
            include(filepath)
        end
    end
end
