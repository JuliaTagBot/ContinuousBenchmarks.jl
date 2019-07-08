using CmdStan, Turing, ContinuousBenchmarks

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "bernoulli-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "bernoulli-stan.model.jl"))

include(joinpath(ContinuousBenchmarks.DATA_DIR, "toy-data", "gdemo-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.MODELS_DIR, "toy-models", "gdemo-stan.model.jl"))

stan_model_name = "simplegauss"
simplegaussstan = Stanmodel(name=stan_model_name, model=simplegaussstanmodel, nchains=1);

rc, simple_gauss_stan_sim = stan(simplegaussstan, simplegaussstandata, CmdStanDir=ContinuousBenchmarks.CMDSTAN_HOME, summary=false);

s_stan = simple_gauss_stan_sim[1:1000, ["s"], :].value[:]
m_stan = simple_gauss_stan_sim[1:1000, ["m"], :].value[:]
sg_time = get_stan_time(stan_model_name)
