function plot_qcv(result, stats = Results.compute_observations(result))
    names = stats[!, STAT_NAME]
    x = eachindex(names)
    y = stats[!, STAT_QCV]
    text = [@sprintf "%.04f" y_i for y_i in y]
    factor_idx = findfirst(isequal(result.factor_name |> string), names)

    # Data
    x_input = [factor_idx]
    x_stable = [i for i in x if y[i] <= y[factor_idx]]
    x_unstable = [i for i in x if y[i] > y[factor_idx]]
    colors = Vector{String}(undef, length(x))

    # Color mapping
    colors[x_stable] .= COLORSCHEME.color10
    colors[x_unstable] .= COLORSCHEME.color9
    colors[x_input] .= COLORSCHEME.color12

    # Bar plot
    Plot(x = names,
         y = y,
         type = :bar,
         text = text,
         marker = (; color = colors))
end
