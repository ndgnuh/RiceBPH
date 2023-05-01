using RiceBPH.Results
using RiceBPH.Visualisations
using GLMakie
using DataFrames
using JDF
using Comonicon
using Printf

@main function main(jdf_dir::String, output::String;
                    column::String, fig_size::Int = 1080)
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
    positions = vec(CartesianIndices((3, 3)))
    axs = Axis[]

    for (i, position) in enumerate(positions)
        # Plot meta data
        sub_df = df_groups[i]
        factor_value = first(sub_df[!, factor])
        title = "$(factor) = $(trunc(factor_value, digits=4))"
        @info "Plotting $title"
        ax = Axis(fig[position.I...]; title)

        # The plot
        st = Results.get_stat(sub_df, column_name)
        μ = st.mean
        σ = st.std
        Visualisations.plot_mean_std!(ax, st.step, μ, σ)
        push!(axs, ax)
    end

    # Sync y axis
    linkyaxes!(axs...)

    save(output, fig)
    @info "Output saved to $(output)"
end
