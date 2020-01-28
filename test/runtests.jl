using ProfileVega
import VegaLite
using Test
using Profile

function profile_test(n)
    for i = 1:n
        A = randn(100,100,20)
        m = maximum(A)
        Am = mapslices(sum, A; dims=2)
        B = A[:,:,5]
        Bsort = mapslices(sort, B; dims=1)
        b = rand(100)
        C = B.*b
    end
end

@testset "ProfileVega" begin

    p1 = @profview profile_test(2)

    @test p1 isa VegaLite.VLSpec
    @test p1.width == 800
    @test p1.height == 400

    ProfileVega.set_default_size(100, 200)
    p2 = @profview profile_test(2)

    @test p2.width == 100
    @test p2.height == 200

    p3 = @profview profile_test(2) width = 500
    @test p3.width == 500
    @test p3.height == 200

    p4 = @profview profile_test(2) height = 600
    @test p4.width == 100
    @test p4.height == 600

    p5 = @profview profile_test(2) height = 600 width = 400
    @test p5.width == 400
    @test p5.height == 600

    Profile.clear()
    @profile profile_test(10)
    p6 = ProfileVega.view()
    @test p6.width == 100
    @test p6.height == 200

    p7 = ProfileVega.view(width = 400, height = 500)
    @test p7.width == 400
    @test p7.height == 500
end
