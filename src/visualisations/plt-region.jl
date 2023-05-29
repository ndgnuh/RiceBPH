using Configurations
using GLMakie
using DataFrames
using Statistics
using ..Results

function autogrid(n::Integer)
    c = trunc(Int, sqrt(n))
    r = c
    while r * c < n
        r += 1
    end
    indices = CartesianIndices((r, c))
    return Iterators.map(Tuple, indices)
end

@option struct RegionData
    path::String
    columns::Vector{String}
    stable_step::Bool
end

function visualize(plot_data::RegionData)
    data = Results.load(plot_data.path)
    columns = plot_data.columns
    factor = Results.get_factor_name(data)
    groups = groupby(data, factor)

    # Create figure
    fig = Figure()
    axes = Axis[]
    grid = autogrid(length(groups))
    for (group, idx) in zip(groups, grid)
        #
        # Axis on a grid
        #
        ax = Axis(fig[idx...];
                  xlabel = L"t")

        #
        # cummulative plotting
        #
        y = zeros(Float32, maximum(group.step) + 1)
        for col in columns
            subgroup = combine(groupby(group, :step), col => mean => col)
            x = subgroup[!, :step]
            μ = subgroup[!, col]
            next_y = y .+ μ
            band!(ax, x, y, next_y)
            next_y .= y
        end
        push!(axes, ax)
    end

    return fig, axes
end
