module TuringTools
# Tools for Turing

using DataFrames
using Dates
using Mustache

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
        Dict(
            "engine" => $(string(alg)),
            "time" => t_elapsed,
            "memory" => mem,
        )
        end)
end

macro tbenchmark_expr(engine, expr)
    quote
        chain, t_elapsed, mem, gctime, memallocs  = @timed $(esc(expr))
        Dict(
            "engine" => $(string(engine)),
            "time" => t_elapsed,
            "memory" => mem,
        )
    end
end

const tmpl_log_string = """
/=======================================================================
| Benchmark Result
|-----------------------------------------------------------------------
| Overview
|-----------------------------------------------------------------------
| Inference Engine  : {{{ engine }}}
| Time Used (s)     : {{{ time }}}
{{#time_stan}}
|   -> time by Stan : {{{ time_stan }}}
{{/time_stan}}
| Mem Alloc (bytes) : {{{ memory }}}
{{#turing}}
|-----------------------------------------------------------------------
| Turing Inference Result
|-----------------------------------------------------------------------
{{/turing}}
{{#turing_items}}
| >> {{{ name }}} <<
| mean = {{{ mean }}}
{{#analytic}}
|   -> analytic = {{{ analytic }}}
{{/analytic}}
{{#anal_diff}}
|        |--*-->  diff = {{{ anal_diff }}}
{{/anal_diff}}
{{#stan}}
|   -> Stan     = {{{ stan }}}
{{/stan}}
{{#stan_diff}}
|        |--*--> diff = {{{ anal_diff }}}
{{/stan_diff}}
{{/turing_items}}
{{#turing_strings}}
| {{.}}
{{/turing_strings}}
{{#note}}
|-----------------------------------------------------------------------
| Note:
|   {{{ note }}}
{{/note}}
\\=======================================================================
"""

function stringify_log(logd::Dict, monitor=[])
    data = Dict{Any, Any}(
        # "name" => logd["name"],
        "engine" => logd["engine"],
        "time" => logd["time"],
        "memory" => logd["memory"],
    )
    haskey(logd, "time_stan") && (data["time_stan"] = logd["time_stan"])
    haskey(logd, "note") && (data["note"] = logd["note"])

    if haskey(logd, "turing")
        data["turing"] = true
        data["turing_items"] = []
        data["turing_strings"] = []
        if isa(logd["turing"], String)
            push!(data["turing_strings"], logd["turing"])
        else
            for (v, m) = logd["turing"]
                (!isempty(monitor) && !(v in monitor)) && continue
                item = Dict{Any, Any}("name" => v)
                item["mean"] = round.(m, digits=3)
                if haskey(logd, "analytic") && haskey(logd["analytic"], v)
                    item["analytic"] = round(logd["analytic"][v], digits=3)
                    diff = abs.(m - logd["analytic"][v])
                    if sum(diff) > 0.2
                        item["anal_diff"] = round(diff, digits=3)
                    end
                end
                if haskey(logd, "stan") && haskey(logd["stan"], v)
                    item["stan"] = round.(logd["stan"][v], digits=3)
                    diff = abs.(m - logd["stan"][v])
                    if sum(diff) > 0.2
                        item["stan_diff"] = round.(diff, digits=3)
                    end
                end
                push!(data["turing_items"], item)
            end
        end
    end
    render(tmpl_log_string, data)
end

function stringify_log(logd::DataFrame, monitor=[])
    return string(logd)
end

print_log(log_data::Dict, monitor=[]) = print(stringify_log(log_data, monitor))

end #module
