@model school8(J, y, sigma) = begin
  mu ~ Flat()
  tau ~ FlatPos(0)
  eta = tzeros(J)
  eta ~ [Normal(0, 1)]
  y ~ MvNormal(mu .+ tau .* eta, sigma)
end
