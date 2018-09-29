using Turing, TuringBenchmarks

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "normal-loc.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "normal-loc.model.jl"))

nlchain = sample(nlmodel, nldata, HMC(1000, 0.05, 3))
print(nlchain[:mu])
