import Base: *, isless

# Auxiliary functions
islastsibling(node::Node) = node.sibling === node

struct LCS{T}
    v::Vector{Tuple{T, T}}
    l::Int
end

LCS(t::Tuple{T, T}, l::Int) where T = LCS{T}([t], l)
isless(seq1::LCS, seq2::LCS) = seq1.l < seq2.l
*(seq1::LCS{T}, seq2::LCS{T}) where T = LCS{T}(vcat(seq1.v, seq2.v), seq1.l + seq2.l)

# No one expects the dynamic programming :-)
# Generally LCS actually can return more than one sequence, but in practice greedy solution should be enough
function lcs(node1::T, node2::T,
    eq = (x, y) -> x == y, is_wildcard = x -> false,
    memo = Dict{Tuple{T, T}, LCS{T}}()) where T

    init = (node1, node2)
    init in keys(memo) && return memo[init]

    if (!is_wildcard(node1) && !is_wildcard(node2) && !eq(node1, node2)) ||
            (!is_wildcard(node1) && is_wildcard(node2)) ||
            (is_wildcard(node1) && !is_wildcard(node2))

        seq1 = islastsibling(node2) ? LCS{T}([], 0) : lcs(node1, node2.sibling, eq, is_wildcard, memo)
        seq2 = islastsibling(node1) ? LCS{T}([], 0) : lcs(node1.sibling, node2, eq, is_wildcard, memo)
        memo[init] = max(seq1, seq2)
   elseif !is_wildcard(node1) && !is_wildcard(node2) && eq(node1, node2)
       if islastsibling(node1) || islastsibling(node2)
           memo[init] = LCS((node1, node2), 1)
       else
           memo[init] = LCS((node1, node2), 1) * lcs(node1.sibling, node2.sibling, eq, is_wildcard, memo)
       end
   else
       seq1 = islastsibling(node2) ? LCS{T}([], 0) : lcs(node1, node2.sibling, eq, is_wildcard, memo)
       seq2 = islastsibling(node1) ? LCS{T}([], 0) : lcs(node1.sibling, node2, eq, is_wildcard, memo)

       seq3 =  if isleaf(node1) || isleaf(node2)
                   LCS((node1, node2), 1)
               else
                   subseq3 = lcs(node1.child, node2.child, eq, is_wildcard, memo)
                   LCS((node1, node2), subseq3.l + 1)
               end
       seq4 = islastsibling(node1) || islastsibling(node2) ? LCS{T}([], 0) : lcs(node1.sibling, node2.sibling, eq, is_wildcard, memo)

       memo[init] = max(seq3*seq4, seq1, seq2)
   end

   return memo[init]
end

# sometimes root node get random narrow branches, in order to compare
# profiles it's easier to remove this spurious branches
function simplify!(node)
    children = collect(node)
    sort!(children, by = x -> length(x.data.span), rev = true)
    for i in 2:length(children)
        prunebranch!(children[i])
    end

    node
end

span(node) = length(node.data.span)
delta(node1, node2) = span(node1) - span(node2)
sf(node) = string(node.data.sf)

function _add_diff_node_to_data(target::T, baseline::T, indent = 0, data = Vector{NamedTuple{(:level, :delta, :x1, :x2, :sf), Tuple{Int,Int,Float64,Float64,String}}}(undef, 0)) where T
    push!(data,
            (level=indent,
            delta=delta(target, baseline),
            x1=target.data.span.start,
            x2=target.data.span.stop+.9,
            sf="$(sf(target))"))
    if target == baseline
        for child in target
            _add_diff_node_to_data(child, child, indent + 1, data)
        end
    else
        seq = lcs(target.child, baseline.child, (x, y) -> sf(x) == sf(y), x -> occursin(r"\[\d+\]:\d+$", sf(x)))
        seq = Dict(seq.v)
        for child in target
            _add_diff_node_to_data(child, get(seq, child, child), indent + 1, data)
        end
    end

    data
end

function _plotdiffflamegraph(target, baseline; kwargs...)
    data = _add_diff_node_to_data(target, baseline)
    domain = sort([extrema(map(x -> x.delta, data))..., 0])
    if domain[1] == 0
        range = ["#d0d0d0", "#d73027"]
        domain = domain[[1, 3]]
    elseif domain[3] == 0
        range = ["#528fe0", "#d0d0d0"]
        domain = domain[[1, 3]]
    else
        range = ["#528fe0", "#d0d0d0", "#d73027"]
    end

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
        color={field="delta", type="quantitative",
            scale={
                domain=domain,
                range=range
            },
            legend={title=nothing, orient=:bottom}},
        tooltip=:sf,
        title="Diff Profile Results"
    )
end


"""
    ProfileVega.diffview(baseline, target=Profile.fetch(); kwargs...)

View differential flamegraph which allow one to compare performance before and after a code change. Colors corresponds to
`target` - `baseline` delta,
If a frame appeared more times in `target`, it is red, less times, it is blue. The saturation is relative to the delta.

Typically it should be used together with `@profbase`. `@profdiffview` accepts all [FlameGraphs](https://github.com/timholy/FlameGraphs.jl) `kwargs` as well as
the following options:

    - `width` - width of the chart in pixels
    - `height`- height of the chart in pixels
    - `negate` - default: false. If `false` shows `target` flamechart with colorization relative to `baseline`.
        If `true` shows `baseline` flamechart with colorization relative to `target`.
    - `simplify` - default: true. Removes spurious branches (all small span branches originated from root).

"""
function diffview(baseline, target::Vector{UInt64}=Profile.fetch(); kwargs...)
    target = FlameGraphs.flamegraph(target; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)
    baseline = FlameGraphs.flamegraph(baseline; filter(x -> !(x[1] in fieldnames(Options)), kwargs)...)

    if get(kwargs, :simplify, _options.simplify)
        target = simplify!(target)
        baseline = simplify!(baseline)
    end

    if get(kwargs, :negate, _options.negate)
        return _plotdiffflamegraph(baseline, target; kwargs...)
    else
        return _plotdiffflamegraph(target, baseline; kwargs...)
    end
end

"""
    @profbase f(args...)

Returns the stack frame which can be used later in `diffview` function. Typical usage of this macro

```
baseline = @profbase myfunction()
```
"""
macro profbase(ex)
    return quote
        Profile.clear()
        Profile.@profile $(esc(ex))
        deepcopy(Profile.fetch())
    end
end

"""
    @profdiffview baseline f(args...)

Clear the Profile buffer, profile `f(args...)`, and view differential flamegraph which allow one to
compare performance before and after a code change. Colors corresponds to `target` - `baseline` delta,
If a frame appeared more times in `target`, it is red, less times, it is blue. The saturation is relative to the delta.

Typically it should be used together with `@profbase`. `@profdiffview` accepts all [FlameGraphs](https://github.com/timholy/FlameGraphs.jl) `kwargs` as well as
the following options:

    - `width` - width of the chart in pixels
    - `height`- height of the chart in pixels
    - `negate` - default: false. If `false` shows `target` flamechart with colorization relative to `baseline`.
        If `true` shows `baseline` flamechart with colorization relative to `target`.
    - `simplify` - default: true. Removes spurious branches (all small span branches originated from root).

#### Example
```
baseline = @profbase myfun()
@profdiffview baseline mymodifiedfun() combine=false width=1200 height=800
```
"""
macro profdiffview(baseline, ex, args...)
    return quote
        Profile.clear()
        Profile.@profile $(esc(ex))
        diffview($(esc(baseline)); $(esc.(args)...))
    end
end
