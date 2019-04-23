module Config

using Logging
using Pkg

const config = Dict{String, Any}()

function load(path::String)
    merge!(config, Pkg.TOML.parsefile(path))
end

function load()
    env = get(ENV, "ENV", "priv")
    load(pwd() * "/config/app.$(env).toml")
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
