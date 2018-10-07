using Turing, TuringBenchmarks
using JLD2, FileIO, Profile, ProfileView

setadbackend(:reverse_diff)
turnprogress(false)

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda-stan.model.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda.model.jl"))

data = map(ind -> ldastandata[1][ind], ["K", "V", "M", "N", "w", "doc", "beta", "alpha"])
sample(ldamodel(data...), HMC(2, 0.025, 10))
Profile.clear()
@profile sample(ldamodel(data...), HMC(20, 0.025, 10))

ProfileView.svgwrite("ldamodel.svg")
