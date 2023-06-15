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
