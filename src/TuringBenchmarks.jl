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

function should_run_benchmark(filename)
    splitext(filename)[2] != ".jl" && return false
    filename ∈ inactive_benchmarks && return false
    filename ∈ broken_benchmarks && return false
    occursin("stan", filename) && return false
    return true
end

const LOG_URL = "http://github.turingbenchmarks.ultrahook.com"

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

const SEND_SUMMARY = Ref(true)

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

# Log function
function log2str(logd::Dict, monitor=[])
    str = ""
    str *= ("/=======================================================================") * "\n"
    str *= ("| Benchmark Result for >>> $(logd["name"]) <<<") * "\n"
    str *= ("|-----------------------------------------------------------------------") * "\n"
    str *= ("| Overview") * "\n"
    str *= ("|-----------------------------------------------------------------------") * "\n"
    str *= ("| Inference Engine  : $(logd["engine"])") * "\n"
    str *= ("| Time Used (s)     : $(logd["time"])") * "\n"
    if haskey(logd, "time_stan")
        str *= ("|   -> time by Stan : $(logd["time_stan"])") * "\n"
    end
    str *= ("| Mem Alloc (bytes) : $(logd["mem"])") * "\n"
    if haskey(logd, "turing")
        str *= ("|-----------------------------------------------------------------------") * "\n"
        str *= ("| Turing Inference Result") * "\n"
        str *= ("|-----------------------------------------------------------------------") * "\n"
        for (v, m) = logd["turing"]
            if isempty(monitor) || v in monitor
                str *= ("| >> $v <<") * "\n"
                str *= ("| mean = $(round.(m, digits=3))") * "\n"
                if haskey(logd, "analytic") && haskey(logd["analytic"], v)
                    str *= ("|   -> analytic = $(round(logd["analytic"][v], digits=3)), ")
                    diff = abs.(m - logd["analytic"][v])
                    diff_output = "diff = $(round(diff, digits=3))"
                    if sum(diff) > 0.2
                        # TODO: try to fix this
                        #print_with_color(:red, diff_output*"\n")
                        print(diff_output*"\n")
                        str *= (diff_output) * "\n"
                    else
                        str *= (diff_output) * "\n"
                    end
                end
                if haskey(logd, "stan") && haskey(logd["stan"], v)
                    str *= ("|   -> Stan     = $(round.(logd["stan"][v], digits=3)), ")
                    println(m, logd["stan"][v])
                    diff = abs.(m - logd["stan"][v])
                    diff_output = "diff = $(round.(diff, digits=3))"
                    if sum(diff) > 0.2
                        # TODO: try to fix this
                        #print_with_color(:red, diff_output*"\n")
                        print(diff_output*"\n")
                        str *= (diff_output) * "\n"
                    else
                        str *= (diff_output) * "\n"
                    end
                end
            end
        end
    end
    if haskey(logd, "note")
        str *= ("|-----------------------------------------------------------------------") * "\n"
        str *= ("| Note:") * "\n"
        note = logd["note"]
        str *= ("| $note") * "\n"
    end
    str *= ("\\=======================================================================") * "\n"
end

print_log(logd::Dict, monitor=[]) = print(log2str(logd, monitor))

function send_log(logd::Dict, monitor=[])
    benchmarks_commit_str = githeadsha((Base.@__DIR__) |> dirname)
    @assert benchmarks_commit_str != ""

    turing_commit_str = githeadsha(turingpath())
    @assert turing_commit_str != ""

    time_str = Dates.format(now(), "dd-u-yyyy-HH-MM-SS")
    logd["created"] = time_str
    logd["turing_commit"] = turing_commit_str
    logd["bench_commit"] = benchmarks_commit_str
    if SEND_SUMMARY[]
        HTTP.open("POST", TuringBenchmarks.LOG_URL) do io
            write(io, JSON.json(logd))
        end
    end
end

function gen_mkd_table_for_commit(commit)
    # commit = "f4ca7bfc8a63e5a6825ec272e7dffed7be623b31"
    api_url = "https://api.mlab.com/api/1/databases/benchmark/collections/log?q={%22commit%22:%22$commit%22}&apiKey=Hak1H9--KFJz7aAx2rAbNNgub1KEylgN"
    res = get(api_url)
    # print(res)

    json = JSON.parse(read(res, String))
    # json[1]

    mkd  = "| Model | Turing | Stan | Ratio |\n"
    mkd *= "| ----- | ------ | ---- | ----- |\n"
    for log in json
        modelName = log["name"]
        tt, ts = log["time"], log["time_stan"]
        rt = tt / ts
        tt, ts, rt = round(tt, digits=2), round(ts, digits=2), round(rt, digits=2)
        mkd *= "|$modelName|$tt|$ts|$rt|\n"
    end

    mkd
end


#=
"""
Function for visualization topic models.

Usage:

    vis_topic_res(samples, K, V, avg_range)

- `samples` is the chain return by `sample()`
- `K` is the number of topics
- `V` is the size of vocabulary
- `avg_range` is the end point of the running average
"""
function vis_topic_res(samples, K, V, avg_range)
    phiarr = mean(samples[:phi][1:avg_range])

    phi = Matrix(0, V)
    for k = 1:K
        phi = vcat(phi, phiarr[k]')
    end

    df = DataFrame(Topic = vec(repmat(collect(1:K)', V, 1)),
                Word = vec(repmat(collect(1:V)', 1, K)),
                Probability = vec(phi))

    return @df df plot(:Word, [:Topic], colour = [:Probability])
end
=#

include("config.jl")
include("reporter.jl")
include("runner.jl")
include("AppServer.jl")

end #module
