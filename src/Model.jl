module Model

using Random
using Agents
using DataFrames
using ImageFiltering
using Colors
using DelimitedFiles
using Base: @kwdef

const SHORT_WING = true
const LONG_WING = false
const MODEL_NAME = "Rice-Brown Plant Hopper"

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

    # Running paramters
    #= energy_miss::Float32 = 0.025 =#
    age_init::Int16 = 168
    age_reproduce::Int16 = 504
    age_old::Int16 = 600
    age_die::Int16 = 720
    pr_egg_death::Float32 = 0.0025
    pr_old_death::Float32 = 0.04
    pr_reproduce_shortwing::Float32 = 0.188f0
    pr_reproduce_longwing::Float32 = 0.157f0
    offspring_max::Int8 = 12
    offspring_min::Int8 = 5
    energy_max::Float32 = 1.0
    energy_transfer::Float32 = 0.1
    energy_consume::Float32 = 0.025
    energy_move::Float32 = 0.2
    energy_reproduce::Float32 = 0.8
    moving_speed_shortwing::Int8 = 1
    moving_speed_longwing::Int8 = 2
end

function Base.iterate(params::ModelParams)
    (k => getproperty(params, k) for k in propertynames(params))
end

"""
    create_model_properties(; model_params...)::NamedTuple

Return model properties from raw model properties. 
Parameters are the fields of `ModelParams`.
The return has all the parameters plus some extra properties,
it also has a `parameters` key to access to all the raw parameters.
Not all keys have to be provided since there are default parematers.
See `ModelParams`.
"""
function create_model_properties(; model_params...)
    # Constructing a ModelParams helps us guard which parameters
    # is needed, while customizing modified parameters without
    # having to write a tons of repetitive code
    params = ModelParams(; model_params...)

    # Maps initialization
    local food
    try
        food = readdlm(params.envmap, ',', Float32)
    catch e
        food = readdlm(params.envmap, '\t', Float32)
    end

    pr_eliminate = init_pr_eliminate(params.init_pr_eliminate, food)
    eliminate_positions = let P = findall(!iszero, pr_eliminate)
        convert.(Tuple, P)
    end

    # Model properties
    props = (;
        iterate(params)..., # put thiss first because it should be overriden
        parameters=Dict(iterate(params)), # For easy result saving
        food=food,
        death_natural=0,
        death_predator=0,
        pr_eliminate=pr_eliminate,
        pr_eliminate_positions=eliminate_positions,
        energy_full=1.0 - params.energy_transfer,
        move_directions=Dict(
            SHORT_WING => neighbors_at(params.moving_speed_shortwing),
            LONG_WING => neighbors_at(params.moving_speed_longwing)
        ),
        pr_reproduce=Dict(
            SHORT_WING => params.pr_reproduce_shortwing,
            LONG_WING => params.pr_reproduce_longwing
        )
    )
    return props
end

"""
                                                                                                                        	gencrop_3x3(::Type{T})

Generate a 3x3 rice map with type `T`.
"""
function gencrop_3x3(T::DataType=Float32)
    flower_position = [31:35; 61:65]
    nan = convert(T, NaN)
    one_ = one(T)
    return food = [
        begin
            if x in flower_position || y in flower_position
                nan
            else
                one_
            end
        end
        for (x, y) in Iterators.product(1:100, 1:100)
    ]
end

Base.@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float16
    age::Int
    isfemale::Bool
    isshortwing::Bool
end

function init_model(; seed=nothing, kwargs...)
    rng = MersenneTwister(seed)
    properties = create_model_properties(; kwargs...)

    # MODEL
    food = properties.food
    space = GridSpace(size(food); periodic=false)
    scheduler = Schedulers.by_id
    model = ABM(BPH, space; scheduler=scheduler, properties=properties, rng=rng)

    # AGENTS CREATION
    init_position = Symbol(properties.init_position)
    positions = let p = if init_position === :corner
            Iterators.product(1:5, 1:5)
        elseif init_position === :random_c1
            Iterators.product(1:(size(food, 1)÷2), 1:size(food, 1))
        elseif init_position === :random_c2
            Iterators.product(1:(size(food, 1)÷3), 1:size(food, 1))
        elseif init_position === :border
            Iterators.product(1:5, 1:size(food, 1))
        else
            @assert false "Postition not in [:corner, :random_c1, :random_c2, :border]"
        end
        filter(pos -> !isnan(food[pos...]), collect(p))
    end
    for _ in 1:(properties.init_nb_bph)
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
    if (agent.age ≥ model.age_init && agent.energy ≥ model.energy_move) && (
        agent.energy ≥ model.energy_full ||
        isnan(model.food[x, y]) ||
        rand(model.rng) > (model.food[x, y] * 0.5)
    )
        thres = rand(model.rng)
        directions = filter(model.move_directions[agent.isshortwing]) do (dx, dy)
            food = get(model.food, (x + dx, y + dy), -1.0)
            thres ≤ (isnan(food) / 2 + !isnan(food) * food)
        end
        if isempty(directions)
            walk!(agent, rand(model.rng, model.move_directions[agent.isshortwing]), model)
        else
            walk!(agent, rand(model.rng, directions), model)
        end
    end

    # Eat conditionally
    if model.food[x, y] > 0 && agent.age ≥ model.age_init
        transfer = min(#
            model.energy_transfer,
            model.food[x, y],
            model.energy_max - agent.energy,
        )
        model.food[x, y] -= transfer
        agent.energy += transfer
        # min(agent.energy + transfer, model.energy_max)
    end

    # Reproduce conditionally
    if (
        agent.isfemale && # is female
        agent.age ≥ model.age_reproduce && # Old enough
        agent.energy ≥ model.energy_reproduce && # Energy requirement
        rand(model.rng) ≤ model.pr_reproduce[agent.isshortwing] # Have RNG Jesus by your side
    )
        nb_offspring = rand(model.rng, (model.offspring_min):(model.offspring_max))
        isshortwing = rand(model.rng, Bool)
        for _ = 1:nb_offspring
            id = nextid(model)
            agent = BPH(;
                id=id,
                pos=agent.pos,
                energy=0.4,
                age=0,
                isfemale=rand(model.rng, Bool),
                isshortwing=isshortwing
            )
            add_agent_pos!(agent, model)
        end
        agent.energy -= 0.1
    end

    # Die conditionally
    if (agent.energy ≤ 0) || # Exausted
       (agent.age ≥ model.age_die) || # Too old
       (
           model.age_die > agent.age ≥ model.age_old && # Old
           rand(model.rng) ≤ model.pr_old_death # And weak
       ) ||
       (
           agent.age < model.age_init && # Young
           rand(model.rng) ≤ model.pr_egg_death # And weak
       ) # then
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

# Data collection functions

function num_healthy_rice(model)
    return count(@. model.food >= 0.5)
end
function is_alive(agent)
    return agent.energy > 0
end

const AGENT_DATA = [(is_alive, count)]
const MODEL_DATA = [num_healthy_rice]

"""
    run_simulation(; num_steps::Int, seed=nothing, kwargs...)

Run RiceBPH simulation, return the result dataframe. `kwargs` are passed to `init_model`
"""
function run_simulation(; num_steps::Int=2880, seed=nothing, kwargs...)
    model, agent_step!, model_step! = init_model(;
        kwargs...,
        seed=seed
    )
    adf, mdf = run!(
        model,
        agent_step!,
        model_step!,
        num_steps;
        adata=AGENT_DATA,
        mdata=MODEL_DATA
    )
    return rightjoin(adf, mdf; on=:step)
end

"""
    get_result_filename(; prefix="", suffix="", kwargs...)

Return the result file name from of `kwargs`.
"""
Base.@pure function get_result_filename(; prefix="", suffix="", kw_...)
    kw = Dict(kw_)
    for (k, v) in kw
        if v isa AbstractString
            kw[k] = basename(v)
        end
    end

    name = join(["$(key)=$(kw[key])"
                 for (key) in sort!(collect(keys(kw)))], "-")
    return "$(prefix)$(name)$(suffix)"
end

"""
    create_experiments; kwargs...)

Return a list of `ModelParams`, `kwargs` should have the
same keys as `ModelParams`, but the types are the lifted
to an iterable container of `{T}` where `T` is the type
of the parameters.
"""
function create_experiments(; mode=Iterators.product, kwargs...)
    num_values = (k => length(v) for (k, v) in kwargs)
    params = map(keys(kwargs)) do key
        values = kwargs[key]
        map(values) do value
            return (key => value)
        end
    end
    experiments = map(Iterators.product(params...)) do (paramset)
        name = get_result_filename(; paramset...)
        params = ModelParams(; paramset...)
        return name => params
    end
    return experiments[:]
end

# END MODULE
end
