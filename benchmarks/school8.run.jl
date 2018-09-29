using Turing, TuringBenchmarks
using Mamba: describe
using HTTP: get, post, put

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "school8-stan.data.jl"))
include(joinpath(TuringBenchmarks.BENCH_DIR, "school8.model.jl"))

data = deepcopy(schools8data[1])
delete!(data, "tau")

# chn = sample(school8(data=data), HMC(2000, 0.75, 5))

@tbenchmark(HMC(20, 0.75, 5), school8, data)
bench_res = @tbenchmark(HMC(2000, 0.75, 5), school8, data)
# bench_res[4].names = ["phi[1]", "phi[2]", "phi[3]", "phi[4]"]
logd = build_logd("School 8", bench_res...)

# describe(chn)

include(splitdir(Base.@__DIR__)[1]*"/benchmarks/school8-stan.run.jl")

logd["stan"] = stan_d
logd["time_stan"] = get_stan_time("schools8")

print_log(logd)
#send_log(logd)
