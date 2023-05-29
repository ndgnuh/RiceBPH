using ..Results
using Statistics
using Colors
const COLORS = distinguishable_colors(9, [RGB(1, 1, 1), RGB(0, 0, 0)], dropseed = true,
                                      lchoices = range(0, stop = 50, length = 15))

@enum VizPreset begin
    StatsBoxPlot
    MeanStd # Over whole time steps
    Region
end

function get_preset(name::String)
    matched = filter(instances(VizPreset)) do inst
        lowercase(string(inst)) == lowercase(name)
    end
    @assert (length(matched)>0) "No preset named $(name), list of presets are $(instances(VizPreset))"
    return first(matched)
end

# Mapping
function visualize(preset::VizPreset, a...; kw...)
    visualize(Val(preset), a...; kw...)
end
function visualize(preset::AbstractString, a...; kw...)
    visualize(get_preset(preset), a...; kw...)
end

"""
    visualize(::Val{MeanStd}, data, column; stable = stable)


"""
function visualize(::Val{MeanStd}, data, column; stable = false)
    factor = Results.get_factor_name(data)
    fig = Figure()
    ax = Axis(fig[1, 1];
              xlabel = "Time step",
              ylabel = L"%$(latex_name(column))")
    t = Results.get_timesteps(data, stable)
    for (i, group) in enumerate(groupby(data, factor))
        # Visual setup
        value = group[begin, factor]
        label = L"%$(latex_name(factor)) = %$value"
        color = COLORS[i]

        # Data setup
        agg = combine(groupby(group, :step),
                      column => mean => :μ,
                      column => std => :σ)
        μ = agg.μ[t]
        σ = agg.σ[t]

        # Plot
        band!(ax, t, μ - σ, μ + σ; color = (color, 0.15f0))
        lines!(ax, t, μ; color, label)
    end
    axislegend(ax)
    return fig
end
