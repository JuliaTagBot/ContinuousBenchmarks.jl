module TuringBenchmarks

__precompile__(false)

using Statistics, Dates, HTTP, JSON

export @tbenchmark,
    benchmark_models,
    benchmark_files,
    get_stan_time,
    build_logd,
    send_log,
    print_log,
    getbenchpath,
    should_run_benchmark

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

function should_run_benchmark(filename)
    splitext(filename)[2] != ".jl" && return false
    filename ∈ inactive_benchmarks && return false
    filename ∈ broken_benchmarks && return false
    occursin("stan", filename) && return false
    return true
end

const MODELS_DIR = abspath(joinpath(@__DIR__, "..", "models"))
const STAN_MODELS_DIR = abspath(joinpath(MODELS_DIR, "stan-models"))

const DATA_DIR = abspath(joinpath(@__DIR__, "..", "data"))
const STAN_DATA_DIR = abspath(joinpath(DATA_DIR, "stan-data"))

const BENCH_DIR = abspath(joinpath(@__DIR__, "..", "benchmarks"))
const SIMULATIONS_DIR = abspath(joinpath(@__DIR__, "..", "simulations"))


include("utils.jl")

using .Utils

include("cmdstan_home.jl")
const CMDSTAN_HOME = cmdstan_home()

# Get running time of Stan
function get_stan_time(stan_model_name::String)
    s = readlines(pwd() * "/tmp/$(stan_model_name)_samples_1.csv")
    println(s[end - 1])
    m = match(r"(?<time>[0-9]+.[0-9]*)", s[end - 1])
    parse(Float64, m[:time])
end

# Run benchmark
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
    benchmarks_head = githeadsha((Base.@__DIR__) |> dirname)
    @assert benchmarks_head != ""

    turing_head = githeadsha(turingpath())
    @assert turing_head != ""

    time_str = Dates.format(now(), "dd-u-yyyy-HH-MM-SS")
    logd["created"] = time_str
    logd["turing_commit"] = turing_head
    logd["bench_commit"] = benchmarks_head
end


include("config.jl")
include("reporter.jl")
include("runner.jl")
include("AppServer.jl")

end #module
