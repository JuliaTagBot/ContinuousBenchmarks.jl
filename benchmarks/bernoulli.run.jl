using Turing, TuringBenchmarks

using Requests
import Requests: get, post, put, delete, options, FileParam

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "bernoulli-stan.data.jl")
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "bernoulli-stan.model.jl")

tbenchmark("HMC(10, 0.25, 5)", "bermodel", "data=berstandata[1]")

bench_res = tbenchmark("HMC(1000, 0.25, 5)", "bermodel", "data=berstandata[1]")
logd = build_logd("Bernoulli Model", bench_res...)


include(splitdir(Base.@__DIR__)[1]*"/benchmarks/"*"bernoulli-stan.run.jl")
logd["stan"] = Dict("theta" => mean(theta_stan))
logd["time_stan"] = ber_time

print_log(logd)
send_log(logd)
