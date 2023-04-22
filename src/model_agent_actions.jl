function kill_agent_with_stats!(agent, model)
end
const STEP = 1
using Random
using StatsBase
# }}}

# COOLDOWN {{{
function cooldown_preoviposition(rng, isshortwing)
    if isshortwing
        rand(rng, Int16(24 * 3):trunc(Int16, 4.6 * 24))
    else
        rand(rng, trunc(Int16, 24 * 7.2):trunc(Int16, 7.6 * 24))
    end
end

function cooldown_reproduction(rng, isshortwing)
    # min_egg_per_lay / (avg_egg / oviposition / 24)
    # max_egg_per_lay / (avg_egg / oviposition / 24)
    # page 40 BPH: Thread to rice production in asia
    avg_egg = isshortwing ? 300.7f0 : 249.0f0
    min_cd = 5 / (avg_egg / 20.7f0 / 24)
    max_cd = 12 / (avg_egg / 20.7f0 / 24)
    #= avg_cd = 9 / (avg_egg / 20.7f0 / 24) =#
    #= trunc(Int16, randnms(rng, avg_cd::Float32, (24 * 3.0f0)::Float32)) =#
    trunc(Int16, rand(rng, min_cd:STEP:max_cd))
end

function cooldown_egg(agent, model)
    rand(model.rng, (24*6):STEP:(24*13))
end
function cooldown_egg(rng)
    rand(rng, (24*6):STEP:(24*13))
end

function cooldown_nymph(agent, model)
    a, b = agent.isfemale ? (11, 16) : (13, 15)
    rand(model.rng, (24*a):STEP:(24*b))
end
function cooldown_nymph(rng, isfemale::Bool)
    a, b = isfemale ? (11, 16) : (13, 15)
    rand(rng, (24*a):STEP:(24*b))
end

# (form (short), gender (female))
const COOLDOWN_ADULT = Dict((true, true) => (22, 23),
    (false, true) => (27, 28),
    (true, false) => (11, 12),
    (false, false) => (11, 12))
function cooldown_adult(agent, model)
    cooldown_adult(model.rng, agent.isfemale, agent.isshortwing)
end
function cooldown_adult(rng, isfemale, isshortwing)
    a, b = COOLDOWN_ADULT[(isshortwing, isfemale)]
    rand(rng, (24*a):STEP:(24*b))
end
# }}}

# ACTIONS {{{
function agent_action_grow!(
    agent,
    model,
    survival_rate::F,
    next_stage_cooldown,
) where {F}
    if agent.stage_cooldown == 0
        if agent.stage == STAGE_ADULT
            kill_agent!(agent, model)
            return true
        else
            agent.stage += 1
            agent.stage_cooldown = next_stage_cooldown(agent, model)
            return false
        end
    end
    agent.stage_cooldown -= 1
    if agent.stage != STAGE_EGG
        agent.energy -= model.energy_consume
    end
    return false
end

const ALL_DIRECTIONS = let
    s = 1
    w = [(i, j) for (i, j)
         in
         Iterators.product(-s:s, -s:s)
         if i^2 + j^2 <= s^2
    ]
    w[:]
end
function agent_action_move!(agent, model)
    x, y = agent.pos
    should_move = (agent.energy >= model.energy_consume)# && (
    #= isnan(model.food[x, y]) || =#
    #= rand(model.rng, Float32) > (model.food[x, y]) =#
    # )
    if !should_move
        return false
    end

    agent.energy -= model.energy_consume
    all_directions = ALL_DIRECTIONS
    direction_weights = map(all_directions) do (dx, dy)
        food = get(model.food, (x + dx, y + dy), -Inf32)
        weight = isnan(food) ? one(Float32) : food
        # The salt is needed so that when all the weights are
        # equals, the first one is not returned
        salt = rand(model.rng, -9:9) * eps(Float32)
        return weight + salt
    end
    direction = wsample(model.rng, all_directions, direction_weights)
    walk!(agent, direction, model)
end

function agent_action_reproduce!(agent, model)
    if !agent.isfemale
        return
    end

    if agent.reproduction_cooldown > 0
        agent.reproduction_cooldown -= 1
        return
    end


    num_children = rand(model.rng, model.num_min_offsprings:model.num_max_offsprings)
    for i in 1:num_children
        isshortwing = rand(model.rng, Bool)
        bph = BPH(; #
            id=nextid(model),
            pos=agent.pos,
            energy=agent.energy,
            stage=STAGE_EGG,
            isfemale=rand(model.rng, Float32) < FEMALE_RATIO,
            isshortwing=isshortwing,
            reproduction_cooldown=cooldown_preoviposition(model.rng, isshortwing),
            stage_cooldown=cooldown_egg(model.rng))
        add_agent_pos!(bph, model)
    end
    agent.reproduction_cooldown = cooldown_reproduction(model.rng, agent.isshortwing)
    agent.energy -= (model.energy_consume * log1p(num_children))
end

function agent_action_eat!(agent, model)
    x, y = agent.pos
    if isnan(model.food[x, y])
        return
    end

    transfer = min(#
        model.energy_transfer,
        model.food[x, y],
        1 - agent.energy,
    )
    num_same = length(agents_in_position(agent, model))
    transfer = transfer + transfer * exp(-num_same)
    model.food[x, y] -= transfer
    agent.energy += transfer
end
# }}}

# STEPS {{{
function agent_step!(agent, model)
    # position
    if agent.stage == STAGE_EGG
        dead = agent_step_egg!(agent, model)
    end

    if agent.stage == STAGE_NYMPH
        dead = agent_step_nymph!(agent, model)
    elseif agent.stage == STAGE_ADULT
        dead = agent_step_adult!(agent, model)
    end

    if agent.energy <= 1e-3
        kill_agent!(agent, model)
    end

    return
end

function agent_step_egg!(agent, model)
    agent_action_grow!(agent, model, SR_EGG, cooldown_nymph)
end

function agent_step_nymph!(agent, model)
    dead = agent_action_grow!(agent, model, SR_EGG, cooldown_adult)
    if dead
        return dead
    end
    agent_action_move!(agent, model)
    agent_action_eat!(agent, model)
    return false
end

function agent_step_adult!(agent, model)
    dead = agent_action_grow!(agent, model, 0.0f0, (_, _) -> 0)
    if dead
        return dead
    end
    agent_action_move!(agent, model)
    agent_action_eat!(agent, model)
    agent_action_reproduce!(agent, model)
    return false
end
# }}}

# vim: foldmethod=syntax
