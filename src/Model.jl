module Model

using Random
using Agents
using DataFrames
using ImageFiltering
using Colors
using DelimitedFiles
using Base: @kwdef
using Base.Threads: @threads, Atomic, atomic_add!
using Statistics

const SHORT_WING = true
const LONG_WING = false
const MODEL_NAME = "Rice-Brown Plant Hopper"
const STAGE_EGG = 1
const STAGE_NYMPH = 2
const STAGE_ADULT = 3
const STAGES = [STAGE_EGG, STAGE_NYMPH, STAGE_ADULT]

# 1.69:1
const FEMALE_RATIO = 0.63f0

# n eggs -> 0.91n eggs survive
const SR_EGG = 0.915f0
const SR_NYMPH = 0.97f0

include("model_agent_actions.jl")

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
    init_position::String = "corner"
    init_pr_eliminate::Float32 = 0.15

    # Running paramters
    #= energy_miss::Float32 = 0.025 =#
    #= age_init::Int16 = 168 =#
    #= age_reproduce::Int16 = 504 =#
    #= age_old::Int16 = 1100 =#
    #= age_die::Int16 = 1224 =#
    #= pr_egg_death::Float32 = 0.0025 =#
    #= pr_old_death::Float32 = 0.04 =#
    #= pr_reproduce_shortwing::Float32 = 0.188f0 =#
    #= pr_reproduce_longwing::Float32 = 0.157f0 =#
    num_max_offsprings::Int8 = 12
    num_min_offsprings::Int8 = 5
    #= energy_max::Float32 = 1.0 =#
    energy_transfer::Float32 = 0.1
    #= energy_move::Float32 = 0.2 =#
    #= energy_reproduce::Float32 = 0.8 =#
    moving_speed_shortwing::Int8 = 1
    moving_speed_longwing::Int8 = 2
end

@kwdef mutable struct ModelProperties
    # Cache inferable
    params::ModelParams
    food::Matrix{Float32}
    pr_eliminate::Matrix{Float32}
    eliminate_positions::Vector{Tuple{Int,Int}}
    move_directions::Dict
    energy_consume::Float32
    #= pr_reproduce::Dict =#
    #= energy_full::Float32 =#

    # Statistics
    collect_data::Bool = true
    num_eggs::Int = 0
    num_nymphs::Int = 0
    num_macros::Int = 0
    num_brachys::Int = 0
    num_bphs::Int = 0

    # Death
    # By age
    death_eggs::Int = 0
    death_nymphs::Int = 0
    death_macros::Int = 0
    death_brachys::Int = 0
    # By reason
    death_flower::Int = 0
    death_energy::Int = 0

    # Ratio
    r_nymphs::Float32 = 0.0f0
    r_macros::Float32 = 0.0f0
    r_brachys::Float32 = 0.0f0

    # Number of rices
    num_rices::Float32 = 1.0f0

    # ETC
    current_step::Int = 0
end

# Forward property to params
function Base.getproperty(mp::ModelProperties, k::Symbol)
    if hasproperty(mp, k)
        getfield(mp, k)
    else
        getfield(mp.params, k)
    end
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
function create_model_properties(; collect_data=true, model_params...)
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
    props = ModelProperties(;
        params=params,
        food=food,
        pr_eliminate=pr_eliminate,
        eliminate_positions=eliminate_positions,
        energy_consume=params.energy_transfer / 3.0f0, # Eat, Grow, Reproduce
        #= energy_full=1.0 - params.energy_transfer, =#
        move_directions=Dict(
            SHORT_WING => neighbors_at(params.moving_speed_shortwing),
            LONG_WING => neighbors_at(params.moving_speed_longwing),
            3 => neighbors_at(3),
            10 => neighbors_at(10),
            4 => neighbors_at(4)
        )
        #= pr_reproduce=Dict( =#
        #=     SHORT_WING => params.pr_reproduce_shortwing, =#
        #=     LONG_WING => params.pr_reproduce_longwing =#
        #= ) =#
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
    isfemale::Bool
    isshortwing::Bool
    stage::Int8
    stage_cooldown::Int16
    reproduction_cooldown::Int16
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
    init_position = (properties.init_position)
    positions = let p = if init_position === "corner"
            Iterators.product(1:25, 1:25)
        elseif init_position === "random_c1"
            Iterators.product(1:(size(food, 1)÷2), 1:size(food, 1))
        elseif init_position === "random_c2"
            Iterators.product(1:(size(food, 1)÷3), 1:size(food, 1))
        elseif init_position === "border"
            Iterators.product(1:5, 1:size(food, 1))
        else
            @assert false "Postition not in [:corner, :random_c1, :random_c2, :border]"
        end
        filter(pos -> !isnan(food[pos...]), collect(p))
    end
    for _ in 1:(properties.init_nb_bph)
        isshortwing = rand(model.rng, Bool)
        isfemale = rand(model.rng, Float32) < FEMALE_RATIO
        stage = if rand(model.rng) <= 0.3333
            STAGE_EGG
        elseif rand(model.rng) <= 0.7
            STAGE_NYMPH
        else
            STAGE_ADULT
        end

        stage_cooldown = if stage == STAGE_EGG
            cooldown_egg(model.rng)
        elseif stage == STAGE_NYMPH
            cooldown_nymph(model.rng, isfemale)
        else
            cooldown_adult(model.rng, isfemale, isshortwing)
        end

        reproduction_cooldown = if stage == STAGE_ADULT && rand(model.rng, Bool)
            cooldown_reproduction(model.rng, isshortwing)
        else
            cooldown_preoviposition(model.rng, isshortwing)
        end

        bph = BPH(; #
            id=nextid(model),
            pos=rand(model.rng, positions),
            energy=1,
            stage=stage,
            isfemale=isfemale,
            isshortwing=isshortwing,
            reproduction_cooldown=reproduction_cooldown,
            stage_cooldown=stage_cooldown)
        add_agent_pos!(bph, model)
    end

    # RETURN
    return model
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
    m, n = size(food)
    kern = Kernel.gaussian(gauss)
    return imfilter(isnan.(food) * pr_eliminate, kern)
end
"""
    init_pr_eliminate(pr_eliminate::AbstractMatrix)

Identity, guard function
"""
function init_pr_eliminate(pr_eliminate::AbstractMatrix, args...)
    return pr_eliminate
end

# Agents behaviors

# Environment behaviors
function model_step!(model)
    # Rice getting more energy
    # Energy cap is 1.0
    # Dead rice receive no energy
    #= @. model.food = min(model.food + model.food * 1 / 10000, 1) =#
    if model.collect_data
        model.num_rices = let
            total_food = Iterators.filter(!isnan, model.food)
            mean(total_food)
        end


        # Statistics
        num_eggs = 0
        num_nymphs = 0
        num_macros = 0
        num_brachys = 0
        for (idx, agent) in (model.agents)
            stage = agent.stage
            if stage == STAGE_EGG
                num_eggs += 1
            elseif stage == STAGE_NYMPH
                num_nymphs += 1
            elseif agent.isshortwing
                num_brachys += 1
            else
                num_macros += 1
            end
        end
        model.num_eggs = num_eggs
        model.num_nymphs = num_nymphs
        model.num_macros = num_macros
        model.num_brachys = num_brachys

        num_adults = num_nymphs + num_brachys + num_macros
        model.num_bphs = num_adults
        model.r_nymphs = num_nymphs / num_adults
        model.r_macros = num_macros / num_adults
        model.r_brachys = num_brachys / num_adults
    end

    # Randomly select a bph at every flower
    for pos in model.eliminate_positions
        pos = Tuple(pos)
        if isempty(pos, model)
            continue
        end
        for agent in agents_in_position(pos, model)
            pr = sqrt(max(zero(Float32), (1 - agent.energy) * model.pr_eliminate[pos...]))
            if rand(model.rng, Float32) < pr
                kill_agent!(agent, model)
                model.death_flower += 1
            end
        end
    end
end

# Data collection functions

const AGENT_DATA = []
const MODEL_DATA = let
    r_egg_survive(m) = 1 - m.death_eggs / m.num_eggs
    r_nymph_survive(m) = 1 - m.death_nymphs / m.num_nymphs
    [
        :num_rices,
        r_egg_survive,
        r_nymph_survive,
        #= :num_eggs, =#
        #= :num_nymphs, =#
        #= :num_macros, =#
        #= :num_brachys, =#
        :r_nymphs,
        :r_macros,
        #= :r_brachys, =#
    ]
end

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
