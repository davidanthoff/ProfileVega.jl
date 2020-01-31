mutable struct Options
    width::Int
    height::Int
    negate::Bool
    simplify::Bool
end

width(opt::Options) = opt.width
height(opt::Options) = opt.height

function set_default_size(width, height)
    _options.width = width
    _options.height = height
end

function set_options(; kwargs...)
    for opt in fieldnames(Options)
        if opt in keys(kwargs)
            setfield!(_options, opt, kwargs[opt])
        end
    end
end
