module ProfileVega

import FlameGraphs, VegaLite, LeftChildRightSiblingTrees, Profile
using VegaLite: save
using LeftChildRightSiblingTrees: Node, isleaf, prunebranch!

include("options.jl")

const global _options = Options(800, 400, false, true)

include("view.jl")
include("diffview.jl")

export @profview, @profbase, @profdiffview, save

end # module
