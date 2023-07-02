function Base.run(config::PlotMeanStdTimeStep)
    # Collect data from config
    output = config.output
    data = Results.load(config.data)
    column = config.column
    factor = Results.get_factor_name(data)

    #
    # Create figure
    #
    fig = Figure()
    ax = Axis(fig[1, 1];
              xlabel = L"t\, (\mathrm{step})",
              ylabel = L"%$(latex_name(column))")

    #
    # Stable time step or not
    #
    t = Results.get_timesteps(data, config.stable_steps)

    #
    # The actual plot
    #
    for (i, group) in enumerate(groupby(data, factor))
        # Visual setup
        value = group[begin, factor]
        label = L"%$(latex_name(factor)) = %$value"
        color = Visualisations.COLORS[i]

        # Data setup
        agg = combine(groupby(group, :step),
                      column => mean => :μ,
                      column => std => :σ)
        x = agg.step[t]
        μ = agg.μ[t]
        σ = agg.σ[t]

        # Plot
        band!(ax, x, μ - σ, μ + σ; color = (color, config.band_alpha))
        lines!(ax, x, μ; color, label)
    end

    #
    # Axis formatting
    #
    if config.normalize_y
        ylims!(ax, (0, 1))
        ax.yticksize = 0.05
    end
    axislegend(ax)

    GLMakie.save(output, fig)
    @info "Output saved to $(output)"
end
