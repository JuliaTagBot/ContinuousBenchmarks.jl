module TuringBenchmarks

__precompile__(false)

using Statistics, Dates, HTTP, JSON

export @benchmarkd,
    @tbenchmark,
    @tbenchmark_expr,
    benchmark_models,
    benchmark_files,
    get_stan_time,
    build_logd,
    send_log,
    print_log,
    getbenchpath,
    set_benchmark_files

# using StatPlots
# using DataFrames

broken_benchmarks = [# Errors
                     "dyes.run.jl",
                     "kid.run.jl",
                     "negative_binomial.run.jl",
                     "normal-mixture.run.jl",
                     "school8.run.jl",
                     "binomial.run.jl",
                     "binormal.run.jl",
                     "MoC.run.jl",
                     "sv.run.jl",
                     "gdemo-geweke.run.jl",
                     "profile.jl", # segfaults
                     # Freezes
                     "lda.run.jl",
                     # to be fixed
                     "bernoulli.run.jl",
                     "gauss.run.jl",
                     "gdemo.run.jl",
                     ]

# Don't have send_log
inactive_benchmarks = ["binomial.run.jl",
                       "change-point.jl",
                       "dyes.run.jl",
                       "gdemo-geweke.run.jl",
                       "negative_binomial.run.jl",
                       "normal-loc.run.jl",
                       "ode.jl",
                       "optimization.jl",
                       "profile.jl",
                       "sv.run.jl",
                       ]

# NOTE:
# put Stan models before Turing ones if you want to compare them in print_log
const default_model_list = ["gdemo-geweke",
                            # "normal-loc",
                            "normal-mixture",
                            "gdemo",
                            "gauss",
                            "bernoulli",
                            # "negative-binomial",
                            "school8",
                            "binormal",
                            "kid"]

const MODELS_DIR = abspath(joinpath(@__DIR__, "..", "models"))
const STAN_MODELS_DIR = abspath(joinpath(MODELS_DIR, "stan-models"))

const DATA_DIR = abspath(joinpath(@__DIR__, "..", "data"))
const STAN_DATA_DIR = abspath(joinpath(DATA_DIR, "stan-data"))

const BENCH_DIR = abspath(joinpath(@__DIR__, "..", "benchmarks"))
const SIMULATIONS_DIR = abspath(joinpath(@__DIR__, "..", "simulations"))

const PROJECT_PATH = Base.RefValue{Union{Nothing, String}}(nothing)
const EXTERNAL_BENCHMARKS_SOURCE = Base.RefValue{Union{Nothing, String}}(nothing)

include("config.jl")
include("utils.jl")
using .Utils

const CMDSTAN_HOME = cmdstan_home()

function set_project_path(project_path::String)
    PROJECT_PATH[] = project_path
end

function should_run_benchmark(filename)
    splitext(filename)[2] != ".jl" && return false
    filename ∈ inactive_benchmarks && return false
    filename ∈ broken_benchmarks && return false
    occursin("stan", filename) && return false
    return true
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
            rethrow(ex)
        end
        return []
    else
        bm_files = Vector{String}()
        for (root, dirs, files) in walkdir(BENCH_DIR)
            for file in files
                if should_run_benchmark(file)
                    bm_file = abspath(joinpath(root, file))
                    push!(bm_files, bm_file)
                end
            end
        end
        return bm_files
    end
end

## Run benchmark
# 1. common
macro benchmarkd(name, expr)
    quote
        result, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        $(string(name)), t_elapsed, mem, result
    end
end

# 2. for Turing
macro tbenchmark(alg, model, data)
    model = :(($model isa String ? eval(Meta.parse($model)) : $model))
    model_dfn = (data isa Expr && data.head == :tuple) ?
        :(model_f = $model($(data)...)) : model_f = :(model_f = $model($data))
    esc(quote
        $model_dfn
        chain, t_elapsed, mem, gctime, memallocs  = @timed sample(model_f, $alg)
        $(string(alg)), t_elapsed, mem, chain, deepcopy(chain)
        end)
end

macro tbenchmark_expr(name, expr)
    quote
        chain, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        $(string(name)), t_elapsed, mem, chain, deepcopy(chain)
    end
end

# Build logd from Turing chain
function build_logd(name::String, engine::String, time, mem, tchain, _)
    mn(c, v) = mean(convert(Array, c[Symbol(v)][min(1001, 9*end÷10):end]))
    Dict(
        "name" => name,
        "engine" => engine,
        "time" => time,
        "mem" => mem,
        "turing" => Dict(v => mn(tchain, v) for v in keys(tchain))
    )
end

print_log(logd::Dict, monitor=[]) = print(stringify_log(logd, monitor))

function send_log(logd::Dict, monitor=[])
    benchmarks_head = ""
    turing_head = ""
    try
        benchmarks_head = githeadsha((Base.@__DIR__) |> dirname)
        turing_head = githeadsha(PROJECT_PATH[])
    catch err
        @warn("Error occurs while sending log")
        if :msg in fieldnames(typeof(err))
            @warn(err.msg)
        end
        return
    end
    @assert benchmarks_head != ""
    @assert turing_head != ""

    time_str = Dates.format(now(), "dd-u-yyyy-HH-MM-SS")
    logd["created"] = time_str
    logd["turing_commit"] = turing_head
    logd["bench_commit"] = benchmarks_head
end


include("reporter.jl")
include("runner.jl")
include("AppServer.jl")

end #module
