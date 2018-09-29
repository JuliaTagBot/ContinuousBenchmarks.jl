using Turing, TuringBenchmarks
using HTTP: get, post, put

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda-stan.model.jl"))
include(joinpath(TuringBenchmarks.BENCH_DIR, "lda-stan.run.jl"))

# setchunksize(100)
setadbackend(:reverse_diff)
# setadbackend(:forward_diff)

# setadsafe(false)

turnprogress(false)

for (modelc, modeln) in zip([
  # "ldamodel_vec", 
  "ldamodel"
  ], [
    # "LDA-vec", 
    "LDA"
    ])
  @tbenchmark(HMC(2, 0.005, 10), modelc, ldastandata[1])
  bench_res = @tbenchmark(HMC(3000, 0.005, 10), modelc, ldastandata[1])
  bench_res[4].names = ["phi[$k]" for k in 1:ldastandata[1]["K"]]
  logd = build_logd(modeln, bench_res...)
  logd["stan"] = lda_stan_d
  logd["time_stan"] = lda_time
  print_log(logd)
  send_log(logd)
end
