function visualize_qcv(result::Result, obdf::DataFrame = compute_observations(result);
                       plot_options = NamedTuple(), axis_options = NamedTuple())
    # Sort by QCV
    obdf = sort(obdf, [STAT_QCV])
    names = obdf[!, STAT_NAME]
    qcv = obdf[!, STAT_QCV]
    idx = eachindex(names)

    # Index of factor
    factor_idx = findfirst(result.factor_name |> string |> isequal, names)

    colors = [parse(Color, COLORSCHEME.color4), parse(Color, COLORSCHEME.color2)]
    colormap = [i == factor_idx ? colors[1] : colors[2] for i in idx]

    attrs = (;
             bar_labels = map(x -> format(format"%.04f", x), qcv),
             axis = (;
                     yticks = (idx, map(latexify ∘ latex_name, names)),
                     xticks = (0:0.1:1.1),
                     xlabel = "Quartile Coefficent of Variant",
                     ylabel = "Factor",
                     axis_options...),
             direction = :x,
             flip_labels_at = qcv[factor_idx],
             color = colormap,
             plot_options...)
    barplot(idx, qcv; attrs...)
end

function visualize_num_bphs(result)
    fig = Figure()

    # Axis setup
    day_step = 10
    xticks = 0:(day_step * 24):maximum(result.df.step)
    ax = Axis(fig[1, 1],
              xticks = (xticks, (string ∘ Int).(xticks / 24)),
              xlabel = "Day",
              ylabel = "Number of BPH agents")

    # For formatting the plot
    count = 1
    min_y = 0
    max_y = maximum(result.df.num_bphs)

    # Collect the result first
    for group in groupby(result.df, result.factor_name)
        stats = combine(groupby(group, :step)) do row
            (;
             t = first(unique(row.step)),
             μ = mean(row.num_bphs),
             σ = std(row.num_bphs))
        end

        # Collect
        t = stats.t
        μ = stats.μ
        σ = stats.σ

        # Adjust axis scale
        max_y = max(max_y, trunc(Int, maximum(μ + σ) / 100) * 100)
        min_y = min(min_y, trunc(Int, minimum(μ - σ) / 100) * 100)

        # Formatting
        color = COLORSCHEME2[count]
        factor_value = group[!, result.factor_name] |> first
        label = LaTeXString("\$N_I = $(factor_value)\$")

        # Plot mean + std plot with a band and a middle line
        band!(ax, t, μ - σ, μ + σ, color = (color, 0.3))
        lines!(ax, t, μ; linewidth = 2.5, label, color)

        # Increase count
        count = count + 1
    end

    # Reticks y axis
    ax.yticks = min_y:150:max_y
    fig[1, 2] = Legend(fig, ax, "Initial number of BPH agents", framevisible = false,
                       nbanks = 2)
    return fig
end
