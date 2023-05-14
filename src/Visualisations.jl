module Visualisations

using DataFrames
using .Utils: latex_name

include("visualisations/agents.jl")
include("visualisations/recipes.jl")
include("visualisations/presets.jl")

end # Visualisations module
