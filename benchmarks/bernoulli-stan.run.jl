using CmdStan, Turing, ContinuousBenchmarks

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "bernoulli-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "bernoulli-stan.model.jl"))

stan_model_name = "bernoulli"
berstan = Stanmodel(name=stan_model_name, model=berstanmodel, nchains=1);

rc, ber_stan_sim = stan(berstan, berstandata, CmdStanDir=ContinuousBenchmarks.CMDSTAN_HOME, summary=false)

theta_stan = ber_stan_sim[1:1000, ["theta"], :].value[:]
ber_time = get_stan_time(stan_model_name)
