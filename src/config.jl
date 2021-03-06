module Config

using Logging
using Pkg

const config = Dict{String, Any}()

function load(path::String)
    if isfile(path)
        @info "*** Using config file: $path"
        merge!(config, Pkg.TOML.parsefile(path))
        return
    end
    @warn "config file $path not found."
end

function load()
    path = get(ENV, "TBB_CONFIG", nothing)
    if path == nothing
        env = get(ENV, "ENV", "priv")
        path = pwd() * "/config/app.$(env).toml"
        if get(ENV, "TRAVIS", "false") == "true"
            env = "travis"
            path = ((@__DIR__) |> dirname) * "/config/app.$(env).toml"
        end
    end
    load(path)
end

function get_config(key::String, default=nothing)
    length(config) == 0 && load()
    keys = split(key, ".")
    ret = config
    for kitem in keys
        ret = get(ret, kitem, Dict())
    end
    isa(ret, Dict) && length(ret) == 0 ? default : ret
end

function set_config(key::String, value)
    length(config) == 0 && load()
    keys = split(key, ".")
    node = config
    for kitem in keys[1:end-1]
        if haskey(node, kitem)
            node = node[kitem]
        else
            node[kitem] = Dict()
            node = node[kitem]
        end
    end
    node[keys[end]] = value
end

function log_level()
    log_level_str = lowercase(get_config("server.log_level", "debug"))

    (log_level_str == "debug") ? Logging.Debug :
    (log_level_str == "info")  ? Logging.Info  :
    (log_level_str == "warn")  ? Logging.Warn  : Logging.Error
end

end
