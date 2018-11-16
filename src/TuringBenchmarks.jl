module TuringBenchmarks

__precompile__(false)

using Statistics, Dates, HTTP, JSON

export  benchmark_models,
        benchmark_files,
        @tbenchmark, 
        get_stan_time, 
        build_logd, 
        send_log,
        print_log, 
        getbenchpath
        #vis_topic_res

# using StatPlots
# using DataFrames

const LOG_URL = "http://github.turingbenchmarks.ultrahook.com"
const MODELS_DIR = abspath(joinpath(@__DIR__, "..", "models"))
const STAN_MODELS_DIR = abspath(joinpath(MODELS_DIR, "stan-models"))

const DATA_DIR = abspath(joinpath(@__DIR__, "..", "data"))
const STAN_DATA_DIR = abspath(joinpath(DATA_DIR, "stan-data"))

const BENCH_DIR = abspath(joinpath(@__DIR__, "..", "benchmarks"))
const SIMULATIONS_DIR = abspath(joinpath(@__DIR__, "..", "simulations"))

include("cmdstan_home.jl")
const CMDSTAN_HOME = cmdstan_home()

const SEND_SUMMARY = Ref(true)

# NOTE: put Stan models before Turing ones if you want to compare them in print_log
const default_model_list = ["gdemo-geweke",
                            #"normal-loc",
                            "normal-mixture",
                            "gdemo",
                            "gauss",
                            "bernoulli",
                            #"negative-binomial",
                            "school8",
                            "binormal",
                            "kid"]

# Get running time of Stan
function get_stan_time(stan_model_name::String)
    s = readlines(pwd()*"/tmp/$(stan_model_name)_samples_1.csv")
    println(s[end-1])
    m = match(r"(?<time>[0-9]+.[0-9]*)", s[end-1])
    parse(Float64, m[:time])
end

# Run benchmark
macro tbenchmark(alg, model, data)
    model = :(($model isa String ? eval(Meta.parse($model)) : $model))
    model_dfn = data isa Expr && data.head == :tuple ? :(model_f = $model($(data)...)) : model_f = :(model_f = $model($data))
    esc(quote
        $model_dfn
        chain, _, mem, _, _  = @timed sample(model_f, $alg)
        $(string(alg)), sum(chain[:elapsed]), mem, chain, deepcopy(chain)
    end)
end

# Build logd from Turing chain
function build_logd(name::String, engine::String, time, mem, tchain, _)
    Dict(
        "name" => name,
        "engine" => engine,
        "time" => time,
        "mem" => mem,
        "turing" => Dict(v => mean(tchain[Symbol(v)][1001:end]) for v in keys(tchain))
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
    dir_old = pwd()
    cd(splitdir(Base.@__DIR__)[1])
    commit_str = replace(split(read(pipeline(`git show --summary `, `grep "commit"`), String), " ")[2], "\n"=>"")
    cd(dir_old)
    time_str = "$(Dates.format(now(), "dd-u-yyyy-HH-MM-SS"))"
    logd["created"] = time_str
    logd["commit"] = commit_str
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

function benchmark_models(model_list=default_model_list; send = true)
    println("Turing benchmarking started.")
    for model in model_list
        try
            _benchmark_model(model, send=send)
        catch err
            println("Error running the benchmark $model.")
            if :msg in fieldnames(typeof(err))
                println(err.msg)
            end
        end
    end
    println("Turing benchmarking completed.")
end

function benchmark_files(file_list=default_model_list; send = true)
    println("Turing benchmarking started.")    
    for file in file_list
        try
            _benchmark_file(file, send = send)
        catch err
            println("Error running the benchmark $file.")
            if :msg in fieldnames(typeof(err))
                println(err.msg)
            end
        end
    end
    println("Turing benchmarking completed.")
end

function _benchmark_model(modelname; send = true)
    println("Benchmarking `$modelname` ... ")
    _benchmark_file(modelname, send=send, model = true)
    println("`$modelname` ✓")
    return 
end

getbenchpath(modelname) = joinpath(TuringBenchmarks.BENCH_DIR, "$(modelname).run.jl")

function _benchmark_file(fileormodel; send = true, model = false)
    if model
        include_arg = "TuringBenchmarks.getbenchpath(\"$fileormodel\")"
    else
        filepath = fileormodel
        println("Benchmarking `$filepath` ... ")
        include_arg = "\"$(replace(filepath, "\\"=>"\\\\"))\""
    end
    julia_path = joinpath(Sys.BINDIR, Base.julia_exename())
    send_code = send ? "TuringBenchmarks.SEND_SUMMARY[] = true;" : "TuringBenchmarks.SEND_SUMMARY[] = false"

    job = `$julia_path -e
                "using CmdStan, Turing, TuringBenchmarks;
                CmdStan.set_cmdstan_home!(TuringBenchmarks.CMDSTAN_HOME);
                $send_code
                include($include_arg);"`
    println(job); run(job)
    !model && println("`$filepath` ✓")
    return 
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

end #module
