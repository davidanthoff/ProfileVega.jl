using ProfileVega
import VegaLite
using Test

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

end
