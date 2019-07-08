using Turing, ContinuousBenchmarks

include(joinpath(ContinuousBenchmarks.DATA_DIR, "toy-data", "gdemo-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.MODELS_DIR, "toy-models", "gdemo.model.jl"))

@tbenchmark(HMC(20, 0.1, 3), simplegaussmodel, simplegaussstandata[1]["x"])
bench_res = @tbenchmark(HMC(2000, 0.1, 3), simplegaussmodel, simplegaussstandata[1]["x"])
logd = build_logd("Simple Gaussian Model", bench_res...)
logd["analytic"] = Dict("s" => 49/24, "m" => 7/6)

#include(joinpath(ContinuousBenchmarks.BENCH_DIR, "gauss-stan.run.jl"))

#logd["stan"] = Dict("s" => mean(s_stan), "m" => mean(m_stan))
#logd["time_stan"] = sg_time

print_log(logd)
send_log(logd)
