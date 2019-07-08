module ContinuousBenchmarks

__precompile__(false)

using JSON

export @benchmarkd,
    set_project_path,
    set_benchmark_files,
    get_benchmark_files

include("config.jl")
include("utils.jl")
using .Utils

const BENCH_DIR = abspath(joinpath(@__DIR__, "..", "benchmarks"))
const PROJECT_PATH = Base.RefValue{Union{Nothing, String}}(nothing)
const EXTERNAL_BENCHMARKS_SOURCE = Base.RefValue{Union{Nothing, String}}(nothing)

function set_project_path(project_path::String)
    PROJECT_PATH[] = project_path
end

function set_benchmark_files(source::String)
    EXTERNAL_BENCHMARKS_SOURCE[] = source
end

function get_benchmark_files()
    if EXTERNAL_BENCHMARKS_SOURCE[] != nothing
        try
            source = EXTERNAL_BENCHMARKS_SOURCE[]
            eval(Meta.parse("""include("$source")"""))
            return BENCHMARK_FILES
        catch ex
            @warn "No benchmarks defined in $(EXTERNAL_BENCHMARKS_SOURCE[])"
        end
        return []
    else
        bm_files = Vector{String}()
        for (root, dirs, files) in walkdir(BENCH_DIR)
            for file in files
                if file == "example.jl" # only run example by default
                    bm_file = abspath(joinpath(root, file))
                    push!(bm_files, bm_file)
                end
            end
        end
        return bm_files
    end
end

## Run benchmark
macro benchmarkd(name, expr)
    quote
        result, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        $(string(name)), result, t_elapsed, mem, gctime, memallocs
    end
end


include("turing-tools.jl")
include("reporter.jl")
include("runner.jl")
include("AppServer.jl")

end #module
