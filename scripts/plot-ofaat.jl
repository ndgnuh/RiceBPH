using RiceBPH.Results
using RiceBPH.Visualisations
using GLMakie
using DataFrames
using JDF
using Comonicon
using Printf

function label_format(column::String)
    prefix = if startswith(column, "num")
        "Numbers of "
    elseif startswith(column, "pct")
        "Percentage of "
    else
        ""
    end
    name = split(column, "_")[end]
    name = replace(name, "_" => " ", "bph" => "BPH")
    return "$(prefix) $(name)"
end

@main function main(jdf_dir::String, output::String;
                    column::String, fig_size::Int = 1080, grid_size = 3,
                    keepaxis::Bool = false, xhours::Bool = false)
    # Load and prepare data
    column_name = Symbol(column)
    df = Results.load(jdf_dir)

    #
    # Group by the OFAAT factor
    #
    factor = Results.get_factor_name(df)
    df_groups = groupby(df, factor)

    #
    # Plotting
    #
    fig = Figure(resolution = (fig_size * 16 ÷ 9, fig_size))
    positions = vec(CartesianIndices((grid_size, grid_size)))
    axs = Axis[]

    for (i, position) in enumerate(positions)
        # Plot meta data
        sub_df = df_groups[i]
        factor_value = first(sub_df[!, factor])
        title = "$(factor) = $(trunc(factor_value, digits=4))"
        @info "Plotting $title"
        ax = Axis(fig[position.I...]; title)
        ax.ylabel = label_format(column)
        ax.xlabel = xhours ? "Hours" : "Days"

        # The plot
        st = Results.get_stat(sub_df, column_name)
        μ = st.mean
        σ = st.std
        x = xhours ? st.step : (st.step / 24.0f0)
        Visualisations.plot_mean_std!(ax, x, μ, σ)
        push!(axs, ax)
    end

    # Sync y axis
    if !keepaxis
        linkyaxes!(axs...)
    end

    save(output, fig)
    @info "Output saved to $(output)"
end
