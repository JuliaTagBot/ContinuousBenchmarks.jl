using Turing, TuringBenchmarks
using Turing: VarName, @VarName
using ForwardDiff: Dual

optRes = ">>> Runtime of ? for 1000 times <<<\n"
optRes *= "Pure function with symbol    : "

function f1()
    x = rand(Normal(0, 1))
end

t1 = @elapsed for i = 1:10000 f1() end

optRes *= "$t1\n"

optRes *= "Low-level API with symbol    : "

@model m2() = begin
    x = Turing.assume(nothing, Normal(0, 1), VarName(:x,:x,"",1), vi)[1]
end

f2 = m2()

t2 = @elapsed for i = 1:10000 f2() end

optRes *= "$t2\n"

optRes *= "~ notation with symbol       : "

@model m3() = begin
    x ~ Normal(0, 1)
end

f3 = m3()

t3 = @elapsed for i = 1:10000 f3() end

optRes *= "$t3\n"

optRes *= "~ notation with expression   : "

@model m4() = begin
    x = tzeros(1)
    x[1] ~ Normal(0, 1)
end


f4 = m4()

t4 = @elapsed for i = 1:10000 f4() end

optRes *= "$t4\n"

optRes *= "Low-level API with expression: "

@model m5() = begin
    x = tzeros(1)
    x[1] = Turing.assume(nothing, Normal(0, 1), VarName(:x,:x,"",1), vi)[1]
end

f5 = m5()

t5 = @elapsed for i = 1:10000 f5() end

optRes *= "$t5\n"

optRes *= "Pure function with expression: "

f6() = begin
    x = Vector{Real}(undef, 1)
    x[1] = rand(Normal(0, 1))
end

t6 = @elapsed for i = 1:10000 f6() end

optRes *= "$t6\n"

turnprogress(false)

optRes *= ">>> Pre-allocation? <<<\n"

run_total = 5

#= #broken

optRes *= "LDA (normal): "

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "lda-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "lda.model.jl"))

data = map(ind -> ldastandata[1][ind], ["K", "V", "M", "N", "w", "doc", "beta", "alpha"])
ts = Float64[]
for run = 1:run_total
    ok = false
    chn = nothing
    counter = 0
    chn = sample(ldamodel_vec(data...), HMC(2000, 0.01, 5))
    t = sum(chn[:elapsed])
    push!(ts, t)
end
optRes *= "$ts, mean=$(mean(ts)), var=$(var(ts))\n"
=#

optRes *= "MoC (normal): "

include(joinpath(TuringBenchmarks.STAN_DATA_DIR, "MoC-stan.data.jl"))
include(joinpath(TuringBenchmarks.STAN_MODELS_DIR, "MoC.model.jl"))

ts2 = Float64[]

data = map(ind -> nbstandata[1][ind], ["K", "V", "M", "N", "z", "w", "doc", "alpha", "beta"])
for run = 1:run_total
    ok = false
    chn = nothing
    chn = sample(nbmodel(data...), HMC(100, 0.01, 5))
    t = sum(chn[:elapsed])
    push!(ts2, t)
end

optRes *= "$ts2, mean=$(mean(ts2)), var=$(var(ts2))\n"

#= #broken 
optRes *= "LDA (pre-alloc): "

global theta = Matrix{Real}(undef, 2, 25)
global phi = Matrix{Real}(undef, 5, 2)

data = map(ind -> ldastandata[1][ind], ["K", "V", "M", "N", "w", "doc", "beta", "alpha"])
ts3 = Float64[]
for run = 1:run_total
    ok = false
    chn = nothing
    chn = sample(ldamodel_vec(data...), HMC(100, 0.01, 5))
    ok = true
    t = sum(chn[:elapsed])
    push!(ts3, t)
end

optRes *= "$ts3, mean=$(mean(ts3)), var=$(var(ts3))\n"
=#

optRes *= "MoC (pre-alloc): "

theta = Vector{Real}(undef, 4)
phi = Vector{Vector{Real}}(undef, 4)
for k = 1:4
    phi[k] = Vector{Real}(undef, 10)
end
log_theta = Vector{Real}(undef, 4)
log_phi = Vector{Real}(undef, 4)

@model nbmodel(K, V, M, N, z, w, doc, alpha, beta) = begin
    theta ~ Dirichlet(alpha)
    # phi = Array{Any}(K)
    for k = 1:K
        phi[k] ~ Dirichlet(beta)
    end

    log_theta = log.(theta)
    Turing.acclogp!(vi, sum(log_theta[z]))

    log_phi = map(x->log.(x), phi)
    lp = mapreduce(n->log_phi[z[doc[n]]][w[n]], +, 1:N)
    Turing.acclogp!(vi, lp)

    phi
end

ts4 = Float64[]
data = map(ind -> nbstandata[1][ind], ["K", "V", "M", "N", "z", "w", "doc", "alpha", "beta"])
for run = 1:run_total
    chn = sample(nbmodel(data...), HMC(100, 0.01, 5))
    t = sum(chn[:elapsed])
    push!(ts4, t)
end

optRes *= "$ts4, mean=$(mean(ts4)), var=$(var(ts4))\n"

optRes *= ">>> Gen VarName <<<\n"

t = @elapsed for i = 1:1000
    sym, idcs, csym = @VarName x[i]
    str = reduce(*, map(idx -> string(idx), idcs), init="")
    VarName(csym, sym, str, 1)
end

optRes *= "1st Run: \n"
optRes *= "Time : $t\n"

t = @elapsed for i = 1:1000
    sym, idcs, csym = @VarName x[i]
    str = reduce(*, map(idx -> string(idx), idcs), init="")
    VarName(csym, sym, str, 1)
end

optRes *= "2nd Run: \n"
optRes *= "Time : $t\n"

using ForwardDiff

optRes *= "realpart(): \n"

ds = [Dual{Nothing,Float64,10}(rand()) for i = 1:1000]

t_map = @elapsed for i = 1:1000 map(d -> d.value, ds) end
t_list = @elapsed for i = 1:1000 Float64[ds[i].value for i = 1:length(ds)] end

optRes *= "Map realpart: $t_map\n"
optRes *= "List realpart: $t_list\n"

optRes *= "Constructing Dual numbers: \n"

SEEDS = ForwardDiff.construct_seeds(ForwardDiff.Partials{44,Float64})
dps = SEEDS[11]

t_dualnumbers = @elapsed for _ = 1:(44*2000*5) ForwardDiff.Dual{Nothing, Float64, 44}(1.1, dps) end

optRes *= "44*2000*5 times: $t_dualnumbers\n"
