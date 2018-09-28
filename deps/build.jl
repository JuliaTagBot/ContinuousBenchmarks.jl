using Pkg, TuringBenchmarks

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

# Download and uncompress cmdstan
if !haskey(ENV, "CMDSTAN_HOME") || ENV["CMDSTAN_HOME"] == ""
    # Make the cmdstan home directory

    CMDSTAN = abspath(joinpath("..", "cmdstan"))
    if !ispath(CMDSTAN)
        mkdir(CMDSTAN)
    end

    # Get cmdstan and uncompress it from its url in deps/cmdstan_url.txt

    cmdstan_url = strip(String(read("cmdstan_url.txt")))
    compressed = splitdir(cmdstan_url)[2]
    dirname = splitext(compressed)[1]
    cmdstan_home = joinpath(CMDSTAN, dirname)
    current_dir = pwd()
    cd(CMDSTAN)
    if !ispath(compressed)
        Pkg.add("HTTP")
        import HTTP
        compressedfile = HTTP.get(cmdstan_url)
        write(compressed, compressedfile.body)
    end
    Pkg.add(["ZipFile", "InfoZIP"])
    import InfoZIP
    InfoZIP.unzip(compressed, CMDSTAN)
    cd(current_dir)
    println("CMDStan is installed at path: $cmdstan_home")

    # Wrie the src file that sets ENV["CMDSTAN_HOME"]

    write(joinpath("..", "src", "cmdstan_home.jl"), "cmdstan_home() = \"$(replace(cmdstan_home, "\\"=>"\\\\"))\"")
else
    write(joinpath("..", "src", "cmdstan_home.jl"), "cmdstan_home() = $(ENV["CMDSTAN_HOME"])")
end
