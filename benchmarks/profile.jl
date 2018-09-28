using Turing, TuringBenchmarks
using HDF5, JLD2, FileIO, ProfileView

setadbackend(:reverse_diff)
turnprogress(false)

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl")
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda-stan.model.jl")

sample(ldamodel(data=ldastandata[1]), HMC(2, 0.025, 10))
Profile.clear()
@profile sample(ldamodel(data=ldastandata[1]), HMC(2000, 0.025, 10))

ProfileView.svgwrite("ldamodel.svg")
