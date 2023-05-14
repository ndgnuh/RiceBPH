module Visualisations

using Configurations
using Colors
using DataFrames

using ..Utils: latex_name

const COLORS = let
    lchoices = range(0, stop = 50, length = 15)
    color_seeds = [RGB(0, 0, 0), RGB(1, 1, 1)]
    dropseed = true
    distinguishable_colors(9, color_seeds; dropseed, lchoices)
end

include("visualisations/agents.jl")
include("visualisations/plt-mean-std.jl")
include("visualisations/plt-region.jl")

@option struct PlotConfig
    data::Union{MeanStdData, RegionData}
    output::String
    normalize_y::Bool
end

function visualize(config::PlotConfig)
    data = config.data
    fig, axes = visualize(data)
    #
    # Normalize y axis to (0, 1)
    #
    if config.normalize_y
        for ax in axes
            ylims!(ax, (0, 1))
        end
    end

    #
    # Write to output or just display
    #
    if config.output == "show"
        scene = display(fig)
        wait(scene)
    else
        save(config.output, fig)
        @info "Output written to $(config.output)"
    end
end

end # Visualisations module
