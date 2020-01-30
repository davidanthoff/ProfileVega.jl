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

# No one expects the dynamic programming
function lcs(node1::Vector{T}, node2::Vector{T}, eq = (x, y) -> x == y) where T
    memo = Dict((T[], T[]) => Set{Vector{Tuple{T, T}}}())
    stack = [(node1, node2)]
    while !isempty(stack)
        l1, l2 = stack[end]
        if isempty(l1) || isempty(l2)
            memo[(l1, l2)] = Set{Vector{Tuple{T, T}}}()
            pop!(stack)
            continue
        end
        if eq(l1[end], l2[end])
            if !((l1[1:end - 1], l2[1:end - 1]) in keys(memo))
                push!(stack, (l1[1:end - 1], l2[1:end - 1]))
            else
                pop!(stack)
                if isempty(memo[(l1[1:end - 1], l2[1:end - 1])])
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()), Set([[(l1[end], l2[end])]]))
                else
                    for seq in memo[(l1[1:end - 1], l2[1:end - 1])]
                        push!(seq, (l1[end], l2[end]))
                    end
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()),
                        (memo[(l1[1:end - 1], l2[1:end - 1])]))
                end
            end
        else
            if !((l1[1:end-1], l2) in keys(memo))
                push!(stack, (l1[1:end-1], l2))
            elseif !((l1, l2[1:end-1]) in keys(memo))
                push!(stack, (l1, l2[1:end-1]))
            else
                pop!(stack)
                p1 = isempty(memo[(l1[1:end-1], l2)]) ? 0 : length(collect(memo[(l1[1:end-1], l2)])[1])
                p2 = isempty(memo[(l1, l2[1:end-1])]) ? 0 : length(collect(memo[(l1, l2[1:end-1])])[1])

                if p1 > p2
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()), memo[(l1[1:end-1], l2)])
                elseif p1 < p2
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()), memo[(l1, l2[1:end-1])])
                else
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()), memo[(l1[1:end-1], l2)])
                    union!(get!(memo, (l1, l2), Set{Vector{Tuple{T, T}}}()), memo[(l1, l2[1:end-1])])
                end
            end
        end
    end
    memo[(node1, node2)]
end

function _add_diff_node_to_data!(node, indent, status, data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,Int,Float64,Float64,String}}}(undef, 0))
    push!(data,
        (level=indent,
        status=status,
        x1=node.data.span.start,
        x2=node.data.span.stop+.9,
        sf="$(clear_sf(node))\t$(length(node.data.span))\t0"))
    for child in node
        _add_diff_node_to_data!(child, indent+1, 0, data)
    end
    data
end

function clear_sf(node)
    # m = match(r"(.*)REPL\[[\d]+\](.*)", string(node.data.sf))
    m = match(r".*REPL\[[\d]+\](.*)", string(node.data.sf))
    m != nothing ? string(m[1]) : string(node.data.sf)
end
eq(x, y) = clear_sf(x) == clear_sf(y)

function _add_diff_node_to_data(target::T, baseline::T, indent = 0, data = Vector{NamedTuple{(:level, :status, :x1, :x2, :sf), Tuple{Int,Int,Float64,Float64,String}}}(undef, 0)) where T
    cb = collect(baseline)
    if isempty(cb)
        # no need to compare, may proceed further without baseline
        _add_diff_node_to_data!(target, indent, length(target.data.span) - length(baseline.data.span), data)
    else
        ct = collect(target)
        sequences = lcs(ct, cb, eq)
        if isempty(sequences)
            # target and baseline completely diverge, just proceed further without baseline
            _add_diff_node_to_data!(target, indent, length(target.data.span) - length(baseline.data.span), data)
        else
            push!(data,
                (level=indent,
                status=length(target.data.span) - length(baseline.data.span),
                x1=target.data.span.start,
                x2=target.data.span.stop+.9,
                sf="$(clear_sf(target))\t$(length(target.data.span))\t$(length(baseline.data.span))"))
                #sf=clear_sf(target)))
            #TODO first one will do for now, more complicated heuristics can be used later
            seq = Dict(collect(sequences)[1])
            for node in ct
                if node in keys(seq)
                    _add_diff_node_to_data(node, seq[node], indent+1, data)
                else
                    _add_diff_node_to_data!(node, indent+1, 0, data)
                end
            end
        end
    end
    data
end


function _plotdiffflamegraph(target, baseline; kwargs...)
    data = _add_diff_node_to_data(target, baseline)

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
    target = FlameGraphs.flamegraph(data; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)
    baseline = FlameGraphs.flamegraph(baseline; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)

    return _plotdiffflamegraph(target, baseline; kwargs...)
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
