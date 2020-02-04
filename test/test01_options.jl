module TestOptions

using ProfileVega: _options, set_options, set_default_size, Options, width, height
using Test

@testset "general options setup" begin
    set_options(width = 1000)
    @test width(_options) == 1000

    set_options(height = 600)
    @test height(_options) == 600

    set_options(negate = true)
    @test _options.negate

    set_options(simplify = false)
    @test !_options.simplify
end

@testset "size options" begin
    set_default_size(100, 200)
    @test _options.width == 100
    @test _options.height == 200
end

end # module
