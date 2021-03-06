# Turing.jl version of model at https://github.com/stan-dev/blob/master/basic_estimators/normal_loc.stan

@model nlmodel(y) = begin
  mu ~ Uniform(-10, 10)
  for n = 1:5
    y[n] ~ Normal(mu, 1.0)
  end
  mu
end
