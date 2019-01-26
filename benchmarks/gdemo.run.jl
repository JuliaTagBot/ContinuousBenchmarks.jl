using Turing, TuringBenchmarks


include(joinpath(TuringBenchmarks.DATA_DIR, "toy-data", "gauss.data.jl"))
include(joinpath(TuringBenchmarks.MODELS_DIR, "toy-models", "gauss.model.jl"))

@tbenchmark(PG(20, 2000), gaussmodel, gaussdata)
#bench_res = @tbenchmark(PG(20, 2000), gaussmodel, gaussdata)
#logd = build_logd("Gaussian Model", bench_res...)
#print_log(logd)

@tbenchmark(HMC(20, 0.25, 5), gaussmodel, gaussdata)
#bench_res = @tbenchmark(HMC(2000, 0.25, 5), gaussmodel, gaussdata)
#logd = build_logd("Gaussian Model", bench_res...)
#print_log(logd)

@tbenchmark(Gibbs(20, HMC(10, 0.25, 5, :mu), PG(20, 10, :lam)), gaussmodel, gaussdata)
bench_res = @tbenchmark(Gibbs(200, HMC(10, 0.25, 5, :mu), PG(20, 10, :lam)), gaussmodel, gaussdata)
logd = build_logd("Gaussian Model", bench_res...)
print_log(logd)
send_log(logd)
