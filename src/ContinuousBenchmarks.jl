module ContinuousBenchmarks

__precompile__(false)

using JSON

export @benchmarkd,
    set_benchmark_config_file,
    get_benchmark_files

include("config.jl")

const BENCH_DIR = abspath(joinpath(@__DIR__, "..", "benchmarks"))
const BENCHMARK_CONFIG_FILE = Base.RefValue{Union{Nothing, String}}(nothing)
CONFIG = Dict()

function set_benchmark_config_file(source::String)
    BENCHMARK_CONFIG_FILE[] = source
    try
        source = BENCHMARK_CONFIG_FILE[]
        eval(Meta.parse("""include("$source")"""))
    catch ex
        @warn "Failed to load config file: $(BENCHMARK_CONFIG_FILE[])"
    end
    for item in CONFIG
        Config.set_config(item.first, item.second)
    end
end

function get_benchmark_files()
    if Config.get_config("benchmark_files") != nothing
        return Config.get_config("benchmark_files")
    else
        bm_files = ["example.jl"]
        return map(bm_files) do x joinpath(BENCH_DIR, x) end
    end
end

## Run benchmark
macro benchmarkd(name, expr)
    quote
        result, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        $(string(name)), result, t_elapsed, mem, gctime, memallocs
    end
end

include("utils.jl")
include("turing-tools.jl")
include("reporter.jl")
include("runner.jl")
include("AppServer.jl")

end #module
