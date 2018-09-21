using Turing, TuringBenchmarks
using Stan

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "bernoulli-stan.data.jl")
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "bernoulli-stan.model.jl")

include(splitdir(Base.@__DIR__)[1]*"/toy-models/gdemo-stan.data.jl")
include(splitdir(Base.@__DIR__)[1]*"/toy-models/gdemo-stan.model.jl")

stan_model_name = "simplegauss"
simplegaussstan = Stanmodel(name=stan_model_name, model=simplegaussstanmodel, nchains=1);

rc, simple_gauss_stan_sim = stan(simplegaussstan, simplegaussstandata, CmdStanDir=CMDSTAN_HOME, summary=false);

s_stan = simple_gauss_stan_sim[1:1000, ["s"], :].value[:]
m_stan = simple_gauss_stan_sim[1:1000, ["m"], :].value[:]
sg_time = get_stan_time(stan_model_name)
