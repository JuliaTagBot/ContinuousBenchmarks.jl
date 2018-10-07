using Turing, TuringBenchmarks

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "bernoulli-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "bernoulli.model.jl"))

@tbenchmark(HMC(10, 0.25, 5), bermodel, berstandata[1]["y"])
bench_res = @tbenchmark(HMC(10000, 0.25, 5), bermodel, berstandata[1]["y"])
logd = build_logd("Bernoulli Model", bench_res...)

include(joinpath(TuringBenchmarks.BENCH_DIR, "bernoulli-stan.run.jl"))
logd["stan"] = Dict("theta" => mean(theta_stan))
logd["time_stan"] = ber_time

print_log(logd)
#send_log(logd)
