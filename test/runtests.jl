using Pkg, HTTP, JSON, TuringBenchmarks
snip(str, len) = str[1:min(len, end)]
snipsha(sha) = snip(sha, 7)

Pkg.develop("Turing")
juliaexe_path = joinpath(Sys.BINDIR, Base.julia_exename())
shas_filepath = abspath(joinpath("..", "src", "bench_shas.txt"))
if isfile(shas_filepath) && length(readlines(shas_filepath)) > 0
    function getturingpath()
        splitdir(splitdir(readchomp(`$(juliaexe_path) -e "using Turing; println(pathof(Turing))"`))[1])[1]
    end
    shas = strip.(readlines(shas_filepath))
    HTTP.open("POST", TuringBenchmarks.LOG_URL) do io
        write(io, JSON.json(Dict("start" => join(snipsha.(shas), "_"))))
    end
    for sha in shas
        cd(getturingpath()) do 
            run(`git checkout $sha`)
        end
        run(`$(juliaexe_path) -e 'include("benchmarks.jl"); runbenchmarks(send=true)'`)
    end
    HTTP.open("POST", TuringBenchmarks.LOG_URL) do io
        write(io, JSON.json(Dict("finish" => "")))
    end
else
    run(`$(juliaexe_path) -e 'include("benchmarks.jl"); runbenchmarks(send=false)'`)
end
