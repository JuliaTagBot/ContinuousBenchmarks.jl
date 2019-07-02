using TuringBenchmarks

s = Ref(0)

res = @benchmarkd("Example", for i in 1:100 s[] += i end)

@show s[]

LOG_DATA = Dict(
    "name" => res[1],
    "engine" => "None",
    "time" => res[3],
    "mem" => res[4],
)
