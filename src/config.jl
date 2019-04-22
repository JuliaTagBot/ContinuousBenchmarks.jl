module Config

using Pkg

const config = Dict{String, Any}()

function load(path::String)
    merge!(config, Pkg.TOML.parsefile(path))
end

function load()
    env = get(ENV, "ENV", "dev")
    load((@__DIR__) * "/../config/app.$(env).toml")
end

function get_config(key::String)
    length(config) == 0 && load()
    keys = split(key, ".")
    ret = config
    for kitem in keys
        ret = get(ret, kitem, Dict())
    end
    isa(ret, Dict) && length(ret) == 0 ? nothing : ret
end

end
