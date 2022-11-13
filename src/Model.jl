module Model

using Random
using Agents
using DataFrames
using ImageFiltering
using Colors
using DelimitedFiles
using Base: @kwdef

name = "Rice-Brown Plant Hopper"

"""
    neighbors_at(n::Integer)

Return the directions on the grid.
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

@kwdef struct ModelParams
    # Initialization parameters
    envmap::String
    init_nb_bph::Int = 200
    init_position::Symbol = :corner
    init_pr_eliminate::Float32 = 0.15
    seed::Union{Nothing,Int} = nothing
    # Running paramters
    energy_miss::Float32 = 0.025
    age_init::Int16 = 168
    age_reproduce::Int16 = 504
    age_old::Int16 = 600
    age_die::Int16 = 720
    pr_reproduce::Dict{Bool,Float32} = Dict(true => 0.188, false => 0.157)
    pr_egg_death::Float32 = 0.0025
    pr_old_death::Float32 = 0.04
    offspring_max::Int8 = 12
    offspring_min::Int8 = 5
    energy_max::Float32 = 1.0
    energy_transfer::Float32 = 0.1
    energy_consume::Float32 = 0.025
    energy_move::Float32 = 0.2
    energy_reproduce::Float32 = 0.8
    move_directions::Dict{Bool,Vector} = Dict(true => neighbors_at(1),
                                              false => neighbors_at(2))
end

"""
                                                	gencrop_3x3(::Type{T})

Generate a 3x3 rice map with type `T`.
"""
function gencrop_3x3(T::DataType=Float32)
    flower_position = [31:35; 61:65]
    nan = convert(T, NaN)
    one_ = one(T)
    return food = [begin
                       if x in flower_position || y in flower_position
                           nan
                       else
                           one_
                       end
                   end
                   for (x, y) in Iterators.product(1:100, 1:100)]
end

Base.@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float16
    age::Int
    isfemale::Bool
    isshortwing::Bool
end

function Base.iterate(x::ModelParams)
    props = propertynames(x)
    prop = first(props)
    value = getproperty(x, prop)
    max_index = length(props)
    state = (props, 2, max_index)
    return (prop => value, state)
end

function Base.iterate(x::ModelParams, state)
    props, index, max_index = state
    if index > max_index
        return nothing
    end
    prop = props[index]
    value = getproperty(x, prop)
    return (prop => value, (props, index + 1, max_index))
end

#= function init_model(; envmap, init_nb_bph::Int, init_position, pr_eliminate, seed, kwargs...) =#
#= function init_model(; envmap, init_nb_bph::Int, init_position, pr_eliminate, seed, kwargs...) =#
#=     return init_model(; envmap, init_nb_bph, init_position, pr_eliminate, seed, kwargs...) =#
#= end =#
function init_model(; kwargs...)
    return init_model(ModelParams(; kwargs...))
end
function init_model(params::ModelParams)
    rng = MersenneTwister(params.seed)
    food = collect(transpose(init_envmap(params.envmap)))
    pr_eliminate = init_pr_eliminate(params.init_pr_eliminate, food)
    init_position = Symbol(params.init_position)

    # PROPERTIES

    properties = (food=food,
                  total_bph=params.init_nb_bph,
                  death_natural=0,
                  death_predator=0,
                  pr_eliminate=pr_eliminate,
                  pr_eliminate_positions=convert.(Tuple, findall(!iszero, pr_eliminate)),
                  energy_full=1.0 - params.energy_transfer,
                  params...)

    # MODEL

    space = GridSpace(size(food); periodic=false)
    scheduler = Schedulers.by_id
    model = ABM(BPH, space; scheduler=scheduler, properties=properties, rng=rng)

    # AGENTS CREATION

    positions = let p = if init_position === :corner
            Iterators.product(1:5, 1:5)
        elseif init_position === :random_c1
            Iterators.product(1:(size(food, 1) ÷ 2), 1:size(food, 1))
        elseif init_position === :random_c2
            Iterators.product(1:(size(food, 1) ÷ 3), 1:size(food, 1))
        elseif init_position === :border
            Iterators.product(1:5, 1:size(food, 1))
        else
            @assert false "Postition not in [:corner, :random_c1, :random_c2, :border]"
        end
        filter(pos -> !isnan(food[pos...]), collect(p))
    end
    for _ in 1:(params.init_nb_bph)
        isshortwing = rand(model.rng, Bool)
        bph = BPH(; #
                  id=nextid(model),
                  pos=rand(model.rng, positions),
                  energy=rand(model.rng, 0.4:0.01:0.6),
                  age=rand(model.rng, 0:300),
                  isfemale=rand(model.rng, Bool),
                  isshortwing=isshortwing)
        add_agent_pos!(bph, model)
    end

    # RETURN
    return model, agent_step!, model_step!
end

"""
                                                	init_envmap(filepath::abstractstring)

Return the food map
"""
function init_envmap(filepath::AbstractString)
    content = read(filepath, String)
    if occursin(",", content)
        readdlm(filepath, ',')
    else
        readdlm(filepath)
    end
end

"""
                                                	init_envmap(envmap::AbstractMatrix)

Guard function
"""
function init_envmap(envmap::AbstractMatrix)
    return envmap
end

"""
                                                	init_pr_eliminate(pr_eliminate::Real, food; gauss=2.5)

Return matrix of death pr. Obtained by using gauss kernel to filter the food matrix.
"""
function init_pr_eliminate(pr_eliminate::Real, food; gauss=2.5)
    return imfilter(isnan.(food) * pr_eliminate, Kernel.gaussian(gauss))
end
"""
                                                	init_pr_eliminate(pr_eliminate::AbstractMatrix)

Identity, guard function
"""
function init_pr_eliminate(pr_eliminate::AbstractMatrix, args...)
    return pr_eliminate
end

# Agents behaviors
function agent_step!(agent, model)
    # position
    x, y = agent.pos

    # Older
    agent.age = agent.age + 1

    # Step wise energy loss
    agent.energy = agent.energy - (agent.age ≥ model.age_init) * model.energy_consume

    # Move conditionally
    if (agent.age ≥ model.age_init && agent.energy ≥ model.energy_move) &&
       (agent.energy ≥ model.energy_full ||
        isnan(model.food[x, y]) ||
        rand(model.rng) > (model.food[x, y] * 0.5))
        thres = rand(model.rng)
        directions = filter(model.move_directions[agent.isshortwing]) do (dx, dy)
            food = get(model.food, (x + dx, y + dy), -1.0)
            return thres ≤ (isnan(food) / 2 + !isnan(food) * food)
        end
        if isempty(directions)
            walk!(agent, rand(model.rng, model.move_directions[agent.isshortwing]), model)
        else
            walk!(agent, rand(model.rng, directions), model)
        end
    end

    # Eat conditionally
    if model.food[x, y] > 0 && agent.age ≥ model.age_init
        transfer = min(model.energy_transfer,
                       model.food[x, y],
                       model.energy_max - agent.energy)
        model.food[x, y] -= transfer
        agent.energy += transfer
        # min(agent.energy + transfer, model.energy_max)
    end

    # Reproduce conditionally
    if (agent.isfemale && # is female
        agent.age ≥ model.age_reproduce && # Old enough
        agent.energy ≥ model.energy_reproduce && # Energy requirement
        rand(model.rng) ≤ model.pr_reproduce[agent.isshortwing])
        nb_offspring = rand(model.rng, (model.offspring_min):(model.offspring_max))
        isshortwing = rand(model.rng, Bool)
        for _ in 1:nb_offspring
            id = nextid(model)
            agent = BPH(;
                        id=id,
                        pos=agent.pos,
                        energy=0.4,
                        age=0,
                        isfemale=rand(model.rng, Bool),
                        isshortwing=isshortwing)
            add_agent_pos!(agent, model)
        end
        agent.energy -= 0.1
    end

    # Die conditionally
    if (agent.energy ≤ 0) || # Exausted
       (agent.age ≥ model.age_die) || # Too old
       (model.age_die > agent.age ≥ model.age_old && # Old
        rand(model.rng) ≤ model.pr_old_death) ||
       (agent.age < model.age_init && # Young
        rand(model.rng) ≤ model.pr_egg_death) # then
        kill_agent!(agent, model)
        return nothing
    end

    # End of agent step
end

# Environment behaviors
function model_step!(model)
    # Rice getting more energy
    # Energy cap is 1.0
    # Dead rice receive no energy
    @. model.food = min(model.food + model.food * 0.008f0 * (model.food > 0), 1)

    # Randomly select a bph at every flower
    for pos in model.pr_eliminate_positions
        pos = Tuple(pos)
        if isempty(pos, model)
            continue
        elseif rand(model.rng) < model.pr_eliminate[pos...]
            agents_to_kill = collect(agents_in_position(pos, model))
            n = length(agents_to_kill)
            perm = randperm(model.rng, n)
            for i in Iterators.take(perm, rand(model.rng, 1:3))
                @inbounds kill_agent!(agents_to_kill[i], model)
            end
        end
    end
end

# Plotting ultilities
function ac(model)
    return function (agent)
        if isnan(model.food[agent.pos...])
            return (0, 0, 0)
        elseif agent.age < model.age_init
            (0.0f0, 0.0f0, 1.0f0)
        else
            (1.0f0, 0.0f0, 0.0f0)
        end
    end
end

agent_markers = Dict(true => :circle, false => :utriangle)
function am(agent)
    return agent_markers[agent.isshortwing]
end

function heatarray(model)
    return model.food
end

function video(crop, init_nb_bph, position, pr_eliminate0; seed, kwargs...)
    return video("BPH-$(init_nb_bph)-$(position)-$(pr_eliminate0)-$(seed).mp4",
                 crop,
                 init_nb_bph,
                 position,
                 pr_eliminate0;
                 seed=seed,
                 kwargs...)
end

function video(videopath::String,
               crop,
               init_nb_bph,
               position,
               pr_eliminate0;
               seed,
               frames=2880,
               kwargs...)
    @info "Video seed: $seed"
    model = init_model(crop, init_nb_bph, position, pr_eliminate0; seed=seed, kwargs...)
    return abm_video(videopath,
                     model,
                     agent_step!,
                     model_step!;#
                     frames=frames,
                     framerate=24,
                     ac=ac(model),
                     am=am,
                     heatarray=heatarray,
                     heatkwargs=(nan_color=(1.0, 1.0, 0.0, 0.5),
                                 colormap=[(0, 1.0, 0, i) for i in 0:0.01:1],
                                 colorrange=(0, 1)))
end

# Data collection functions

function num_healthy_rice(model)
    return count(@. model.food >= 0.5)
end
function is_alive(agent)
    return agent.energy > 0
end

const AGENT_DATA = [(is_alive, count)]
const MODEL_DATA = [num_healthy_rice]

# END MODULE
end
