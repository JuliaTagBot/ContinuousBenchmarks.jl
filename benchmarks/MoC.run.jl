using Turing, ContinuousBenchmarks

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "MoC-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "MoC.model.jl"))
#include(joinpath(ContinuousBenchmarks.BENCH_DIR, "MoC-stan.run.jl"))

setadbackend(:reverse_diff)

data = map(ind -> nbstandata[1][ind], ["K", "V", "M", "N", "z", "w", "doc", "alpha", "beta"])
@tbenchmark(HMC(20, 0.01, 5), nbmodel, (data...))
bench_res = @tbenchmark(HMC(5000, 0.01, 5), nbmodel, (data...))
# bench_res = @tbenchmark(HMCDA(1000, 0.65, 0.3), nbmodel, (data...))
# bench_res = @tbenchmark(NUTS(2000, 0.65), nbmodel, (data...))
bench_res[4].names = ["phi[1]", "phi[2]", "phi[3]", "phi[4]"]
logd = build_logd("Mixture-of-Categorical", bench_res...)

#logd["stan"] = stan_d
#logd["time_stan"] = nb_time

print_log(logd)
send_log(logd)
