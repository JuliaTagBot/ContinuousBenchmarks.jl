project_root = (@__DIR__) |> dirname
local_cmdstan_home = abspath(joinpath(project_root, "cmdstan"))

if !haskey(ENV, "CMDSTAN_HOME") || ENV["CMDSTAN_HOME"] == ""
    if !isdir(local_cmdstan_home)
        @warn "Please build package TuringBenchmarks to install CmdStan locally."
    end
    ENV["CMDSTAN_HOME"] = local_cmdstan_home
end
cmdstan_home() = ENV["CMDSTAN_HOME"]
