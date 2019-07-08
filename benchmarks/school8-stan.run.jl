using CmdStan, Turing, ContinuousBenchmarks

# Model taken from https://github.com/goedman/Stan.jl/blob/master/Examples/Mamba/EightSchools/schools8.jl

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "school8-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "school8-stan.model.jl"))

global stanmodel, rc, sim
# stanmodel = Stanmodel(name="schools8", model=eightschools);
stanmodel = Stanmodel(Sample(algorithm=CmdStan.Hmc(CmdStan.Static(0.75*5),CmdStan.diag_e(),0.75,0.0),
  save_warmup=true,adapt=CmdStan.Adapt(engaged=false)),
  num_samples=2000, num_warmup=0, thin=1,
  name="schools8", model=eightschools, nchains=1);

rc, sim = stan(stanmodel, schools8data, CmdStanDir=ContinuousBenchmarks.CMDSTAN_HOME, summary=false)

stan_d = Dict()

for i = 1:8
  stan_d["eta[$i]"] = sim[:, ["eta.$i"], :].value[:]
  stan_d["theta[$i]"] = sim[:, ["theta.$i"], :].value[:]
end

stan_d["mu"] = sim[:, ["mu"], :].value[:]
stan_d["tau"] =sim[:, ["tau"], :].value[:]

for k = keys(stan_d)
  stan_d[k] = mean(stan_d[k])
end

# println("CmdStan time: $stan_time")

# describe(sim)
