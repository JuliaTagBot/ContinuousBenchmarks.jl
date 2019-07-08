# Model and data files don't exist

using Turing, ContinuousBenchmarks
using Mamba: describe
using FileIO, JLD2

include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "sv.model.jl"))

sv_data = load(joinpath(ContinuousBenchmarks.DATA_DIR, "/nips-2017/sv-data.jld2"))["data"]

# setadbackend(:forward_diff)
# setchunksize(1000)
# chain_nuts = sample(model_f, NUTS(sample_n, 0.65))
# describe(chain_nuts)

# setchunksize(5)
# chain_gibbs = sample(model_f, Gibbs(sample_n, PG(50,1,:h), NUTS(1000,0.65,:ϕ,:σ,:μ)))
# describe(chain_gibbs)

turnprogress(false)

mf = sv_model(data=sv_data[1])
chain_nuts = sample(mf, HMC(2000, 0.05, 10))
