using Turing, TuringBenchmarks
using Stan

odeDataRaw = readcsv(joinpath(TuringBenchmarks.DATA_DIR, "toy-data", "ode.csv")

t = Vector{Float64}(odeDataRaw[2:end, 1])
x0 = Vector{Float64}(odeDataRaw[2:end, 2])
x1 = Vector{Float64}(odeDataRaw[2:end, 3])

function sho(t, y, theta, x_r, x_i)
    dydt = Vector{Real}(2)
    dydt[1] = y[2]
    dydt[2] = -y[1] - theta[1] * y[2]

    return dydt
end
