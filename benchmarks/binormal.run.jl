# https://github.com/goedman/Stan.jl/blob/master/Examples/Mamba/Binormal/binormal.jl

using Turing, TuringBenchmarks
using HTTP: get, post, put

include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "binormal-stan.model.jl"))

@tbenchmark(HMC(20, 0.5, 5), binormal, ())
bench_res = @tbenchmark(HMC(2000, 0.5, 5), binormal, ())
# chn = sample(binormal(), HMC(2000,0.5,5))

# describe(chn)

# turing_time = sum(chn[:elapsed])

logd = Dict(
  "name" => "Binormal (sampling from the prior)",
  "engine" => bench_res[1],
  "time" => bench_res[2],
  "mem" => bench_res[3],
  "turing" => Dict("y[1]" => mean(bench_res[4][:y])[1], "y[2]" => mean(bench_res[4][:y])[2])
)

# logd = build_logd("Binormal: sampling from the prior", bench_res...)

include(joinpath(TuringBenchmarks.BENCH_DIR, "binormal-stan.run.jl"))

# logd["stan"] = Dict("s" => mean(s_stan), "m" => mean(m_stan))
logd["time_stan"] = get_stan_time("binormal")

# println("Stan time  : $stan_time")
# println("Turing time: $turing_time")

send_log(logd)
