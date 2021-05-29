module Model

using Random
using Agents
using DataFrames
using ImageFiltering
using CairoMakie: RGBf0, RGBAf0
using InteractiveDynamics

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
        center - (abs(i - center) + abs(j - center))
    end
    dist[center, center] = 0
    map(findall(dist .> 0)) do I
        (I[1] - center, I[2] - center)
    end
end

const default_parameters = (#
    energy_miss=0.025,
    age_init=168,
    age_reproduce=504,
    age_old=600,
    age_die=720,
    pr_reproduce=0.07,
    pr_egg_death=0.0025,
    pr_old_death=0.04,
    offspring_max=12,
    offspring_min=5,
    energy_max=1.0,
    energy_transfer=0.1,
    energy_consume=0.025,
    energy_move=0.2,
    energy_reproduce=0.8,
    move_directions=neighbors_at(2),
)

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
        end for (x, y) in Iterators.product(1:100, 1:100)
    ]
end

Base.@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy
    age::Int
    nb_reproduce::Int
end

function init_model(food, n_bph::Int, init_position::Symbol, pr_killed0; seed, kwargs...)
    food = collect(transpose(food))
    rng = MersenneTwister(seed)
    pr_killed = imfilter(isnan.(food) * pr_killed0, Kernel.gaussian(2.5))
    #pr_killed = pr_killed / maximum(pr_killed) * pr_killed0

    # PROPERTIES

    properties = (#
        food=food,
        total_bph=n_bph,
        death_natural=0,
        death_predator=0,
        pr_killed=pr_killed,
        pr_killed_positions=convert.(Tuple, findall(!iszero, pr_killed)),
        merge(default_parameters, kwargs)...,
    )

    # MODEL

    space = GridSpace(size(food); periodic=false)
    scheduler = Schedulers.by_id
    model = ABM(BPH, space; scheduler=scheduler, properties=properties, rng=rng)

    # AGENTS CREATION

    positions =
        let p = if init_position === :corner
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
    for _ in 1:n_bph
        bph = BPH(; #
            id=nextid(model),
            pos=rand(model.rng, positions),
            energy=rand(model.rng, 0.4:0.01:0.6),
            age=rand(model.rng, 0:300),
            nb_reproduce=0,
        )
        add_agent_pos!(bph, model)
    end

    # RETURN
    return model
end

function init_model(; food, n_bph::Int, init_position, pr_killed0, seed, kwargs...)
    return init_model(food, n_bph, Symbol(init_position), pr_killed; seed=seed, kwargs...)
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
        isone(agent.energy) ||
        isnan(model.food[x, y]) ||
        rand(model.rng) > (model.food[x, y] * 0.5)
    )
        walk!(agent, rand(model.rng, model.move_directions), model)
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
        #min(agent.energy + transfer, model.energy_max)
    end

    # Reproduce conditionally
    if (
        agent.age ≥ model.age_reproduce && # Old enough
        agent.energy ≥ model.energy_reproduce && # Energy requirement
        agent.nb_reproduce < 21 && # Not too much reproduction
        rand(model.rng) ≤ model.pr_reproduce # Have RNG Jesus by your side
    )
        agent.nb_reproduce = agent.nb_reproduce + 1
        nb_offspring = rand(model.rng, (model.offspring_min):(model.offspring_max))
        for _ in 1:nb_offspring
            id = nextid(model)
            agent = BPH(id, agent.pos, 0.4, 0, 0)
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
    alive = @.(model.food > 0)
    @. model.food = min(model.food + model.food * 0.008f0 * alive, 1.0f0)

    # Randomly select a bph at every flower
    for pos in model.pr_killed_positions
        pos = Tuple(pos)
        if isempty(pos, model)
            continue
        elseif rand(model.rng) < model.pr_killed[pos...]
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
            return RGBf0(0, 0, 0)
        elseif agent.age < model.age_init
            RGBf0(0.0f0, 0.0f0, 1.0f0)
        else
            RGBf0(1.0f0, 0.0f0, 0.0f0)
        end
    end
end

function heatarray(model)
    return model.food
end

function video(crop, nb_bph_init, position, pr_killed0; seed, kwargs...)
    return video(
        "BPH-$(nb_bph_init)-$(position)-$(pr_killed0)-$(seed).mp4",
        crop,
        nb_bph_init,
        position,
        pr_killed0;
        seed=seed,
        kwargs...,
    )
end

function video(
    videopath::String, crop, nb_bph_init, position, pr_killed0; seed, frames=2880, kwargs...
)
    @info "Video seed: $seed"
    model = init_model(crop, nb_bph_init, position, pr_killed0; seed=seed, kwargs...)
    return abm_video(
        videopath,
        model,
        agent_step!,
        model_step!;#
        frames=frames,
        framerate=24,
        ac=ac(model),
        heatarray=heatarray,
        heatkwargs=(
            nan_color=nan_color = RGBAf0(1.0, 1.0, 0.0, 0.5),
            colormap=[RGBAf0(0, 1.0, 0, i) for i in 0:0.01:1],
            colorrange=(0, 1),
        ),
    )
end

# END MODULE
end
