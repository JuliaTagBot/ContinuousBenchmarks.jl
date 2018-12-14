# Benchmark Report

## Job properties

*Turing Commits:*
- *mt/autodiff_refactor:* 302e61aeaf71fd1c00d356b0000ee94cf63bb42a
- *master:* 873aaece57def9e5e2ecd83430bbe29c31c1d64b

*TuringBenchmarks commit:* 5adc70098802a5efe3305a034a354e90ae2ec240

## Results:

Below is a table of this job's results, obtained by running the benchmarks found in
[TuringLang/TuringBenchmarks](https://github.com/TuringLang/TuringBenchmarks). The table shows the time ratio of the 2 Turing commits benchmarked. A ratio greater than `1.0` denotes a possible regression (marked with :x:), while a ratio less than `1.0` denotes a possible improvement (marked with :white_check_mark:). Results are subject to noise so small fluctuations around `1.0` may be ignored.

| ID | time ratio |
|----|------------|
`Bernoulli Model - HMC(10000, 0.25, 5)` | 0.96 (0.183 ms / 0.19 ms)  :white_check_mark: |
`Gaussian Model - Gibbs(200, HMC(10, 0.25, 5, :mu), PG(20, 10, :lam))` | 0.66 (58.212 ms / 88.103 ms)  :white_check_mark: |
`Simple Gaussian Model - HMC(2000, 0.1, 3)` | 0.87 (0.104 ms / 0.119 ms)  :white_check_mark: |


