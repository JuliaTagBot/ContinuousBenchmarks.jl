using CmdStan, Turing, ContinuousBenchmarks

#using Mamba: describe

include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "binormal-stan.model.jl"))

global stanmodel, rc, sim1, sim, stan_time
# stanmodel = Stanmodel(name="binormal", model=binorm, Sample(save_warmup=true));
stanmodel = Stanmodel(Sample(algorithm=CmdStan.Hmc(CmdStan.Static(0.5*5),CmdStan.diag_e(),0.5,0.0),
  save_warmup=true,adapt=CmdStan.Adapt(engaged=false)),
  num_samples=2000, num_warmup=0, thin=1,
  name="binormal", model=binorm, nchains=1);

rc, sim1 = stan(stanmodel, CmdStanDir=ContinuousBenchmarks.CMDSTAN_HOME, summary=false)

if rc == 0
  ## Subset Sampler Output
  sim = sim1[1:size(sim1, 1), ["lp__", "y.1", "y.2"], 1:size(sim1, 3)]

  # describe(sim)
end # cd
