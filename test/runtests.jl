using Pkg

Pkg.develop("Turing")
shas_filepath = abspath(joinpath("..", "src", "bench_shas.txt"))
if isfile(shas_filepath) && length(readlines(shas_filepath)) > 0
    function getturingpath()
        splitdir(splitdir(readchomp(`julia -e "using Turing; println(pathof(Turing))"`))[1])[1]
    end
    shas = strip.(readlines(shas_filepath))
    for sha in shas
        cd(getturingpath()) do 
            run(`git checkout $sha`)
        end
        run(`julia -e "include(\\"benchmarks.jl\\"); runbenchmarks(send=true)"`)
    end
else
    run(`julia -e "include(\\"benchmarks.jl\\"); runbenchmarks(send=false)"`)
end
