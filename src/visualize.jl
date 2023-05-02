module Visualisations

using Reexport
using Colors
@reexport using GLMakie
using ..Models

#
# Agent plotting stuffs
#
"""
Color of the flower cells on the heatmap (`#FFC107`).
"""
const FLOWER_COLOR = colorant"#FFC107"

"""
Color of the rice cells on the heatmap, the color is `RGB(0.0, 0.8, 0.0, energy)`
where energy is the energy of the rice cell.
"""
const RICE_COLORS = RGBAf.(0.0f0, 0.8f0, 0.0f0, 0.0f0:0.001f0:1.0f0)
const AGENT_COLORS = Dict(Models.Egg => colorant"#0D47A1",
                          Models.Nymph => colorant"#D32F2F",
                          Models.Adult => colorant"#F44336")

ac(agent) = AGENT_COLORS[agent.stage]
am(_) = :circle

function heatarray(model)
    flower_mask = model.flower_mask
    @. !flower_mask * NaN32 + model.rice_map * flower_mask
end

const heatkwargs = (; nan_color = FLOWER_COLOR,
                    colormap = RICE_COLORS,
                    colorrange = (0, 1))

#
# Result plotting stuffs
#
function plot_mean_std!(ax, x, μ, σ)
    band!(ax, x, μ - σ, μ + σ)
    lines!(ax, x, μ)
end

end
