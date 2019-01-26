# Benchmark Report

## Job properties

*Turing Commits:*
- *mt/type_stability2:* 4220e18905d7fef7ab992efb5e63f46e96e3443c
- *master:* aed8f5c58832b9a118da6b53c3320cddf7af616d

*TuringBenchmarks commit:* 4a823a9ed5a52914f0f05e951dc13c2045924719

## Results:

Below is a table of this job's results, obtained by running the benchmarks found in
[TuringLang/TuringBenchmarks](https://github.com/TuringLang/TuringBenchmarks). The table shows the time ratio of the 2 Turing commits benchmarked. A ratio greater than `1.0` denotes a possible regression (marked with :x:), while a ratio less than `1.0` denotes a possible improvement (marked with :white_check_mark:). Results are subject to noise so small fluctuations around `1.0` may be ignored.

| ID | time ratio |
|----|------------|
`Bernoulli Model - HMC(10000, 0.25, 5)` | 0.57 (0.219 ms / 0.383 ms)  :white_check_mark: |
`Gaussian Model - Gibbs(200, HMC(10, 0.25, 5, :mu), PG(20, 10, :lam))` | 0.82 (131.72 ms / 160.547 ms)  :white_check_mark: |
`Simple Gaussian Model - HMC(2000, 0.1, 3)` | 0.73 (0.201 ms / 0.276 ms)  :white_check_mark: |


