module ProfileVega

import FlameGraphs, VegaLite, LeftChildRightSiblingTrees, Profile
using VegaLite: save

export @profview, save

function _add_node_to_data!(data, node, indent)
    push!(data, (level=indent, status=node.data.status==0 ? "Default" : node.data.status==1 ? "Runtime dispatch" : "Garbage collection", x1=node.data.span.start, x2=node.data.span.stop+.9, sf=string(node.data.sf)))
    for child in node
        _add_node_to_data!(data, child, indent+1)
    end
end

function _plotflamegraph(node)
    data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,String,Float64,Float64,String}}}(undef, 0)    
    _add_node_to_data!(data, node, 0)
    
    return data |> VegaLite.@vlplot(
        :rect,
        transform=[{calculate="datum.level+0.9", as=:level2}],
        selection={grid={type=:interval, bind=:scales}},
        x={:x1, axis=nothing},
        x2=:x2,
        y={"level:q", axis=nothing},
        y2={"level2:q"},
        width=800,
        height=400,
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
    g = FlameGraphs.flamegraph(data; kwargs...)

    return _plotflamegraph(g)
end

"""
    @profview f(args...)

Clear the Profile buffer, profile `f(args...)`, and view the result graphically.
"""
macro profview(ex)
    return quote
        Profile.clear()
        Profile.@profile $(esc(ex))
        view()
    end
end

end # module
