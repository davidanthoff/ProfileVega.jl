module ProfileVega

import FlameGraphs, VegaLite, LeftChildRightSiblingTrees, Profile
using VegaLite: save

export @profview, save

mutable struct Options
    width::Int
    height::Int
end

global _options = Options(800, 400)

function set_default_size(width, height)
    _options.width = width
    _options.height = height
end

function _add_node_to_data!(data, node, indent)
    push!(data, (level=indent, status=node.data.status==0 ? "Default" : node.data.status==1 ? "Runtime dispatch" : "Garbage collection", x1=node.data.span.start, x2=node.data.span.stop+.9, sf=string(node.data.sf)))
    for child in node
        _add_node_to_data!(data, child, indent+1)
    end
end

function _plotflamegraph(node; kwargs...)
    data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,String,Float64,Float64,String}}}(undef, 0)
    _add_node_to_data!(data, node, 0)

    return data |> VegaLite.@vlplot(
        mark={type=:rect, stroke="#505050"},
        transform=[{calculate="datum.level+0.9", as=:level2}],
        selection={grid={type=:interval, bind=:scales},
            highlight={type=:single, on=:mouseover, empty=:none},
            select={type=:multi, empty=:none}},
        x={:x1, axis=nothing},
        x2=:x2,
        y={"level:q", axis=nothing},
        y2={"level2:q"},
        fillOpacity={condition=[
                {selection=:highlight, value=0.6},
                {selection=:select, value=0.5}
            ],
            value=1},
        strokeWidth={condition=[
            {selection=:highlight, value=0.5},
            {selection=:select, value=0.5}
            ],
            value=0},
        width=get(kwargs, :width, _options.width),
        height=get(kwargs, :height, _options.height),
        color={"status:n", legend={title=nothing, orient=:bottom}},
        tooltip=:sf,
        title="Profile Results"
    )
end


function flatten_tree(node, data = Dict{String, Int}())
    data[string(node.data.sf)] = get!(data, string(node.data.sf), []), length(node.data.span))
    for child in node
        flatten_tree(child, data)
    end
    data
end

function _add_diff_node_to_data(node, baseline, indent = 0, data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,Int,Float64,Float64,String}}}(undef, 0))
    diff = length(node.data.span) - get(baseline, string(node.data.sf), length(node.data.span))
    push!(data,
        (level=indent,
        status=diff,
        x1=node.data.span.start,
        x2=node.data.span.stop+.9,
        sf=string(node.data.sf)*"||"*string(length(node.data.span))*"||"*string(get(baseline, string(node.data.sf), 0))))
    for child in node
        _add_diff_node_to_data(child, baseline, indent+1, data)
    end
    data
end

function _plotdiffflamegraph(node, baseline; kwargs...)
    data = _add_diff_node_to_data(node, baseline)

    return data |> VegaLite.@vlplot(
        mark={type=:rect, stroke="#505050"},
        transform=[{calculate="datum.level+0.9", as=:level2}],
        selection={grid={type=:interval, bind=:scales},
            highlight={type=:single, on=:mouseover, empty=:none},
            select={type=:multi, empty=:none}},
        x={:x1, axis=nothing},
        x2=:x2,
        y={"level:q", axis=nothing},
        y2={"level2:q"},
        fillOpacity={condition=[
                {selection=:highlight, value=0.6},
                {selection=:select, value=0.5}
            ],
            value=1},
        strokeWidth={condition=[
            {selection=:highlight, value=0.5},
            {selection=:select, value=0.5}
            ],
            value=0},
        width=get(kwargs, :width, _options.width),
        height=get(kwargs, :height, _options.height),
        color={field="status", type="quantitative", legend={title=nothing, orient=:bottom}},
        tooltip=:sf,
        title="Diff Profile Results"
    )
end

"""
    ProfileVega.view(data=Profile.fetch(); kwargs...)

View profiling results. See [FlameGraphs](https://github.com/timholy/FlameGraphs.jl)
for options for `kwargs`.
"""
function view(data::Vector{UInt64}=Profile.fetch(); kwargs...)
    g = FlameGraphs.flamegraph(data; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)

    return _plotflamegraph(g; kwargs...)
end

"""
    ProfileVega.viewdiff(baseline, data=Profile.fetch(); kwargs...)

View profiling results in comparison to baseline profile. See [FlameGraphs](https://github.com/timholy/FlameGraphs.jl)
for options for `kwargs`.
"""
function viewdiff(baseline, data::Vector{UInt64}=Profile.fetch(); kwargs...)
    g = FlameGraphs.flamegraph(data; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)
    baseline = flatten_tree(FlameGraphs.flamegraph(baseline; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...))

    return _plotdiffflamegraph(g, baseline; kwargs...)
end

"""
    @profview f(args...)

Clear the Profile buffer, profile `f(args...)`, and view the result graphically.
"""
macro profview(ex, args...)
    return quote
        Profile.clear()
        Profile.@profile $(esc(ex))
        view(;$(esc.(args)...))
    end
end

end # module
