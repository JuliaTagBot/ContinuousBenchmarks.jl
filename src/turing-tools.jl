module TuringTools
# Tools for Turing

using Dates

using ..Utils

export @tbenchmark,
    @tbenchmark_expr,
    build_log_data,
    print_log

macro tbenchmark(alg, model, data)
    model = :(($model isa String ? eval(Meta.parse($model)) : $model))
    model_dfn = (data isa Expr && data.head == :tuple) ?
        :(model_f = $model($(data)...)) : model_f = :(model_f = $model($data))
    esc(quote
        $model_dfn
        chain, t_elapsed, mem, gctime, memallocs  = @timed sample(model_f, $alg)
        $(string(alg)), t_elapsed, mem, chain, deepcopy(chain)
        end)
end

macro tbenchmark_expr(name, expr)
    quote
        chain, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        $(string(name)), t_elapsed, mem, chain, deepcopy(chain)
    end
end

# Build log_data from Turing chain
function set_log_info!(log_data::Dict, monitor=[])
    project_dir = unsafe_string(Base.JLOptions().project)
    project_head = ""
    try
        project_head = githeadsha(project_dir)
    catch err
        @warn("Error: failed to get commit info from $project_dir")
        (:msg in fieldnames(typeof(err))) ? @warn(err.msg) : @warn(err)
        return log_data
    end
    @assert project_head != ""

    time_str = Dates.format(now(), "dd-u-yyyy-HH-MM-SS")
    log_data["created"] = time_str
    log_data["project_commit"] = project_head
    return log_data
end

function build_log_data(name::String, engine::String, time, mem, tchain, _)
    mn(c, v) = mean(convert(Array, c[Symbol(v)][min(1001, 9*end÷10):end]))
    turing_data = try
        Dict(v => mn(tchain, v) for v in keys(tchain))
    catch
        string(tchain)[1:min(700, end)]
    end
    log_data = Dict(
        "name" => name,
        "engine" => engine,
        "time" => time,
        "mem" => mem,
        "turing" => turing_data
    )
    set_log_info!(log_data)
end

print_log(log_data::Dict, monitor=[]) = print(stringify_log(log_data, monitor))

end #module
