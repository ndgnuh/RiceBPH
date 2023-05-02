module Visualisations

include("visualisations/agents.jl")
include("visualisations/recipes.jl")

#
# Result plotting stuffs
#
function plot_mean_std!(ax, x, μ, σ; band_kw = NamedTuple(), lines_kw = NamedTuple())
    band!(ax, x, μ - σ, μ + σ; band_kw...)
    lines!(ax, x, μ; lines_kw...)
end

function plot_result(result::DataFrame, type::String)
end

end # Visualisations module
