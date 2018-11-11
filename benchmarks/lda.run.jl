using Turing, TuringBenchmarks

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda-stan.model.jl"))
#include(joinpath(TuringBenchmarks.BENCH_DIR, "lda-stan.run.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda.model.jl"))

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
    data = map(ind -> ldastandata[1][ind], ["K", "V", "M", "N", "w", "doc", "beta", "alpha"])
    @tbenchmark(HMC(2, 0.005, 10), eval(modelc), (data...))
    bench_res = @tbenchmark(HMC(3000, 0.005, 10), eval(modelc), (data...))
    bench_res[4].names = ["phi[$k]" for k in 1:ldastandata[1]["K"]]
    logd = build_logd(modeln, bench_res...)
    #logd["stan"] = lda_stan_d
    #logd["time_stan"] = lda_time
    print_log(logd)
    send_log(logd)
end
