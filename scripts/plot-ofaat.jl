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
    aspect = DataAspect()

    #
    # Plotting
    #
    fig = Figure(resolution = (fig_size, fig_size))
    positions = vec(CartesianIndices((3, 3)))

    for (i, position) in enumerate(positions)
        # Plot meta data
        sub_df = df_groups[i]
        factor_value = first(sub_df[!, factor])
        title = "$(factor) = $(trunc(factor_value, digits=4))"
        ax = Axis(fig[position.I...]; title, aspect)

        # The plot
        st = Results.get_stat(sub_df, column_name)
        μ = st.mean
        σ = st.std
        Visualisations.plot_mean_std!(ax, st.step, μ, σ)
    end

    save(output, fig)
end
