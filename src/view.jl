function _add_node_to_data(node, indent = 0, data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,String,Float64,Float64,String}}}(undef, 0))
    push!(data, (level=indent, status=node.data.status==0 ? "Default" : node.data.status==1 ? "Runtime dispatch" : "Garbage collection", x1=node.data.span.start, x2=node.data.span.stop+.9, sf=string(node.data.sf)))
    for child in node
        _add_node_to_data(child, indent+1, data)
    end
    data
end

function _plotflamegraph(node; kwargs...)
    data =_add_node_to_data(node)

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
        width=get(kwargs, :width, width(_options)),
        height=get(kwargs, :height, height(_options)),
        color={"status:n", legend={title=nothing, orient=:bottom}},
        tooltip=:sf,
        title="Profile Results"
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
