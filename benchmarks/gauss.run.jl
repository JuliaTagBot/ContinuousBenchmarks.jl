using Turing, TuringBenchmarks

using Requests
import Requests: get, post, put, delete, options, FileParam

include(joinpath(TuringBenchmarks.DATA_DIR, "toy-data", "gdemo-stan.data.jl")
include(joinpath(TuringBenchmarks.BENCH_DIR, "toy-models", "gdemo.model.jl")

tbenchmark("HMC(20, 0.1, 3)", "simplegaussmodel", "data=simplegaussstandata[1]")

bench_res = tbenchmark("HMC(2000, 0.1, 3)", "simplegaussmodel", "data=simplegaussstandata[1]")
logd = build_logd("Simple Gaussian Model", bench_res...)
logd["analytic"] = Dict("s" => 49/24, "m" => 7/6)

include(splitdir(Base.@__DIR__)[1]*"/benchmarks/"*"gauss-stan.run.jl")

logd["stan"] = Dict("s" => mean(s_stan), "m" => mean(m_stan))
logd["time_stan"] = sg_time

print_log(logd)
send_log(logd)
