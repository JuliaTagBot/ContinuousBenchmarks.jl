# Benchmark Report

## Job properties

*Turing Commits:*
- *mt/compiler2.0:* 623afa9c69035cc3c1499808c10e8e3573ed4c14
- *master:* 873aaece57def9e5e2ecd83430bbe29c31c1d64b

*TuringBenchmarks commit:* 5454701458ebd907daeb3906d3675003ff8a7c51

## Results:

Below is a table of this job's results, obtained by running the benchmarks found in
[TuringLang/TuringBenchmarks](https://github.com/TuringLang/TuringBenchmarks). The table shows the time ratio of the 2 Turing commits benchmarked. A ratio greater than `1.0` denotes a possible regression (marked with :x:), while a ratio less than `1.0` denotes a possible improvement (marked with :white_check_mark:). Results are subject to noise so small fluctuations around `1.0` may be ignored.

| ID | time ratio |
|----|------------|
`Bernoulli Model - HMC(10000, 0.25, 5)` | 1.12 (0.212 ms / 0.189 ms)  :x: |
`Gaussian Model - Gibbs(200, HMC(10, 0.25, 5, :mu), PG(20, 10, :lam))` | 1.13 (66.232 ms / 58.561 ms)  :x: |
`Simple Gaussian Model - HMC(2000, 0.1, 3)` | 1.12 (0.134 ms / 0.12 ms)  :x: |


