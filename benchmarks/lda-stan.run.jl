using CmdStan, Turing, ContinuousBenchmarks
using Mamba

include(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl"))
include(joinpath(ContinuousBenchmarks.STAN_MODELS_DIR, "lda-stan.model.jl"))

stan_model_name = "LDA"
# ldastan = Stanmodel(Sample(save_warmup=true), name=stan_model_name, model=ldastanmodel, nchains=1);
# To understand parameters, use: ?CmdStan.Static, ?CmdStan.Hmc
ldastan = Stanmodel(Sample(algorithm=CmdStan.Hmc(CmdStan.Static(0.05),CmdStan.diag_e(),0.005,0.0),
  save_warmup=true,adapt=CmdStan.Adapt(engaged=false)),
  num_samples=3000, num_warmup=0, thin=1,
  name=stan_model_name, model=ldastanmodel, nchains=1);

rc, lda_stan_sim = stan(ldastan, ldastandata, CmdStanDir=ContinuousBenchmarks.CMDSTAN_HOME, summary=false);
# lda_stan_sim.names
V = ldastandata[1]["V"]
K = ldastandata[1]["K"]
lda_stan_d_raw = Dict()
for i = 1:K, j = 1:V
  lda_stan_d_raw["phi[$i][$j]"] = lda_stan_sim[1001:end, ["phi.$i.$j"], :].value[:]
end

lda_stan_d = Dict()
for i = 1:K
  lda_stan_d["phi[$i]"] = mean([[lda_stan_d_raw["phi[$i][$k]"][j] for k = 1:V] for j = 1:(ldastan.num_samples-1000)])
end

lda_time = get_stan_time(stan_model_name)
println("CmdStan time: ", lda_time)