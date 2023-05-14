using Configurations
using Statistics
using DataFrames
using GLMakie
using ..Results

@option struct MeanStdData
    path::String
    column::String
    stable_step::Bool
    band_alpha::Float32 = 0.15
end

function visualize(plot_data::MeanStdData)
    #
    # Load results
    #
    data = Results.load(plot_data.path)
    column = plot_data.column
    factor = Results.get_factor_name(data)

    # Create figure
    fig = Figure()
    ax = Axis(fig[1, 1];
              xlabel = "Time step",
              ylabel = L"%$(latex_name(column))")

    # Get stable time step
    t = Results.get_timesteps(data, plot_data.stable_step)
    for (i, group) in enumerate(groupby(data, factor))
        # Visual setup
        value = group[begin, factor]
        label = L"%$(latex_name(factor)) = %$value"
        color = COLORS[i]

        # Data setup
        agg = combine(groupby(group, :step),
                      column => mean => :μ,
                      column => std => :σ)
        x = agg.step[t]
        μ = agg.μ[t]
        σ = agg.σ[t]

        # Plot
        band!(ax, x, μ - σ, μ + σ; color = (color, plot_data.band_alpha))
        lines!(ax, x, μ; color, label)
    end

    # Legend
    axislegend(ax)
    return fig, [ax]
end
