module LDA_SIM

using FileIO, JLD2, Turing, ContinuousBenchmarks

# V <- 5; # words: river, stream, bank, money, loan
# K <- 2; # topics: RIVER, BANK
# M <- 25;  # docs
V = 100
K = 5
M = 10

# alpha <- rep(1/K,K);
# beta <- rep(1/V,V);
alpha = collect(ones(K) / K);
beta = collect(ones(V) / V);

# phi <- array(NA,c(2,5));
# phi[1,] = c(0.330, 0.330, 0.330, 0.005, 0.005);
# phi[2,] = c(0.005, 0.005, 0.330, 0.330, 0.330);
phi = rand(Dirichlet(beta), K)
#println(phi)

# theta <- rdirichlet(M,alpha);
theta = rand(Dirichlet(alpha), M)
#println(theta)

# avg_doc_length <- 10;
avg_doc_length = 1000

# doc_length <- rpois(M,avg_doc_length);
doc_length = rand(Poisson(avg_doc_length), M)

# N <- sum(doc_length);
N = sum(doc_length)

# w <- rep(NA,N);
# doc <- rep(NA,N);
w = Vector{Int}(undef, N)
doc = Vector{Int}(undef, N)

# n <- 1;
# for (m in 1:M) {
#   for (i in 1:doc_length[m]) {
#     z <- which(rmultinom(1,1,theta[m,]) == 1);
#     w[n] <- which(rmultinom(1,1,phi[z,]) == 1);
#     doc[n] <- m;
#     n <- n + 1;
#   }
# }
n = 1
for m = 1:M, i=1:doc_length[m]
    global n
    z = rand(Categorical(theta[:,m]))
    w[n] = rand(Categorical(phi[:,z]))
    doc[n] = m
    n = n + 1
end

ldastandata = [
    Dict(
    "K" => K,
    "V" => V,
    "M" => M,
    "N" => N,
    "w" => w,
    "doc" => doc,
    "alpha" => alpha,
    "beta" => beta,
    # "phi" => phi,
    # "theta" => theta,
    # "D" => M * K + K * V
  )
]

# println(ldastandata)

save(joinpath(ContinuousBenchmarks.STAN_DATA_DIR, "ldastandata.jld2"), "data", ldastandata)

end
