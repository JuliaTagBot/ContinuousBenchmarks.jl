using Turing, ContinuousBenchmarks

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "normal-loc.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "normal-loc.model.jl"))

nlchain = sample(nlmodel(nldata[:y]), HMC(1000, 0.05, 3))
print(nlchain[:mu])
