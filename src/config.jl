module Config

using Logging
using Pkg

const config = Dict{String, Any}()

function load(path::String)
    if isfile(path)
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

function log_level()
    log_level_str = lowercase(get_config("server.log_level", "debug"))

    (log_level_str == "debug") ? Logging.Debug :
    (log_level_str == "info")  ? Logging.Info  :
    (log_level_str == "warn")  ? Logging.Warn  : Logging.Error
end


end
