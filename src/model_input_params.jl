using Base: @kwdef

@kwdef struct InputParams
    map_width::Int = 100
    map_height::Int = 100
    map_tile_type::Symbol = :horizontal
    map_tile_size::Int = 5
    map_tile_number::Int = 3
    initial_bph_region::Tuple{Tuple{Int,Int},Tuple{Int,Int}} = ((0, 15), (0, 15))
    initial_bph_region_y::Symbol = :corner
    initial_bph_number_bph::Int = 200
    age_init::Int16 = 168
    age_reproduce::Int16 = 504
    age_old::Int16 = 600
    age_die::Int16 = 720
    pr_reproduce_shortwing::Float32 = 0.188
    pr_reproduce_longwing::Float32 = 0.157
    pr_egg_death::Float32 = 0.0025
    pr_old_death::Float32 = 0.04
    pr_eliminate_max::Float32 = 0.15
    offspring_max::Int8 = 12
    offspring_min::Int8 = 5
    energy_max::Float32 = 1.0
    energy_transfer::Float32 = 0.1
    energy_consume::Float32 = 0.025
    energy_move::Float32 = 0.2
    energy_reproduce::Float32 = 0.8
    moving_speed_shortwing::Int = 1
    moving_speed_longwing::Int = 2
end

function to_model_properties(params)
    props = Dict()
    for prop in [:moving_speed, :pr_reproduce]
        lw_prop = Symbol(prop, :_longwing)
        sw_prop = Symbol(prop, :_shortwing)
        props[prop] = Dict(true => getproperty(params, sw_prop),
                           false => getproperty(params, lw_prop))
    end
    return NamedTuple(props)
end

"""
```
neighbors_at(n::Integer)
```

Return the directions assuming one can walk `n` step on the grid.
"""
function neighbors_at(n::Integer)
    k = 2 * n + 1
    kern = zeros(Int, k, k)
    center = k ÷ 2 + 1
    dist = map(CartesianIndices(kern)) do I
        i, j = Tuple(I)
        return center - (abs(i - center) + abs(j - center))
    end
    dist[center, center] = 0
    map(findall(dist .> 0)) do I
        return (I[1] - center, I[2] - center)
    end
end

