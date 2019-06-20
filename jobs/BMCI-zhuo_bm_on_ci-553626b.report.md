# Benchmark Report

## Job properties

**Turing Branches**:
- **master**(c3f5c49) **[BASE_BRANCH]**
- **zhuo/bm-on-ci**(553626b) 

**TuringBenchmarks Commit**: a914956

## Results Table:

Below is a table of this job's results, obtained by running the
benchmarks found in
[TuringLang/TuringBenchmarks](https://github.com/TuringLang/TuringBenchmarks). The
table shows the time ratio of the N (N >= 2) Turing commits
benchmarked. A ratio greater than `1.0` denotes a possible regression
(marked with :-1:), while a ratio less than `1.0` denotes a possible
improvement (marked with :+1:). Results are subject to
noise so small fluctuations around `1.0` may be ignored.

| BenchMark    |  TimeRatio(master) |  TimeRatio(zhuo/bm-on-ci) | 
| -----------  |  ----------------------- |  ----------------------- | 
| `Dummy-Benchmark - HMC(1000, 1.5, 3)` |  1.0 (30387.761 ms / 30387.761 ms) :+1: |  0.63 (19156.149 ms / 30387.761 ms) :+1: | 

## Raw Results:

### `Dummy-Benchmark - HMC(1000, 1.5, 3)`
#### On Branch `master`
```javascript
{
  "turing_commit": "c3f5c49c04a2e995d63eabb0305117b7a9db6c25",
  "name": "Dummy-Benchmark",
  "time": 30.387761111,
  "mem": 1880606381,
  "turing": {
    "eval_num": 12003.0,
    "lp": -7.234347309854674,
    "p": 0.7586924165103686
  },
  "created": "20-Jun-2019-06-32-34",
  "bench_commit": "a914956869bfaa72f039659f09e4f3ab65dcce20",
  "engine": "HMC(1000, 1.5, 3)"
}

```

#### On Branch `zhuo/bm-on-ci`
```javascript
{
  "turing_commit": "553626b3bbaa6232b3ab9c7048f99583a603383c",
  "name": "Dummy-Benchmark",
  "time": 19.156148705,
  "mem": 1880455837,
  "turing": {
    "eval_num": 12003.0,
    "lp": -7.970247946264967,
    "p": 0.7926338557818806
  },
  "created": "20-Jun-2019-06-34-44",
  "bench_commit": "a914956869bfaa72f039659f09e4f3ab65dcce20",
  "engine": "HMC(1000, 1.5, 3)"
}

```


