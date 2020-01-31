module TestDiffView

using Test
using LeftChildRightSiblingTrees
using ProfileVega
using VegaLite
using ProfileVega: islastsibling, lcs

eq(x::Node{Int}, y::Node{Int}) = x.data == y.data



@testset "lcs basics" begin
    root1 = Node(1)
    root2 = Node(1)

    res = lcs(root1, root2, eq)
    @test res.l == 1
    @test length(res.v) == 1
    @test res.v[1] == (root1, root2)

    root1 = Node(1)
    root2 = Node(2)

    res = lcs(root1, root2, eq)
    @test res.l == 0
    @test isempty(res.v)
end

@testset "lcs simple sequences" begin
    x1 = Node(1)
    x2 = addsibling(x1, 2)

    y1 = Node(1)
    y2 = addsibling(y1, 2)
    res = lcs(x1, y1, eq)
    @test res.l == 2

    x1 = Node(1)
    x2 = addsibling(x1, 2)
    x3 = addsibling(x2, 3)

    y1 = Node(1)
    y2 = addsibling(y1, 3)

    res = lcs(x1, y1, eq)
    @test res.l == 2
end

@testset "lcs simple wildcard sequences" begin
    wildcard(x) = x.data == 0

    x1 = Node(1)
    x2 = addsibling(x1, 0)
    x3 = addsibling(x2, 2)
    x4 = addsibling(x3, 3)
    x2_1 = addchild(x2, 1)
    x2_2 = addsibling(x2_1, 2)
    x2_3 = addsibling(x2_2, 3)


    y1 = Node(1)
    y2 = addsibling(y1, 2)
    y3 = addsibling(y2, 3)
    y4 = addsibling(y3, 0)
    y4_1 = addchild(y4, 1)
    y4_2 = addsibling(y4_1, 2)
    y4_3 = addsibling(y4_2, 3)

    res = lcs(x1, y1, eq, wildcard)
    @test length(res.v) == 2
    @test res.l == 5
    @test res.v[1] == (x1, y1)
    @test res.v[2] == (x2, y4)
end


function f1(n)
    res = 0
    for _ in 1:n
        res += sum(rand(10_000))
    end

    for _ in 1:n
        res -= sum(rand(10_000))
    end
    res
end

function f2(n)
    res = 0
    for _ in 1:n
        res += sum(rand(20_000))
    end

    for _ in 1:n
        A = randn(10, 10, 10)
        res += maximum(A)
    end

    for _ in 1:n
        res -= sum(rand(5_000))
    end
    res
end

@testset "ProfileVega diffview" begin
    baseline = @profbase f1(2)
    p1 = @profdiffview baseline f2(2)

    @test p1 isa VegaLite.VLSpec
end

end # module
