using Turing, TuringBenchmarks

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "negative_binomial.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "negative_binomial.model.jl"))

# Produce an error.
sample(negbinmodel(negbindata), HMC(1000, 0.02, 1));
