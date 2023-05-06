using Random

#
# Helper
#
"""
    @return_if(expr)

Expand to `if expr then return end`.
"""
macro return_if(expr)
    quote
        if $(esc(expr))
            return
        end
    end
end

#
# Mapping current stage to next stage
#
function get_next_stage(rng, ::Val{Egg}, ::Val{Male}, _)
    stage_cd = randt(rng, Int16, CD_M_ADULT)
    return Nymph, stage_cd
end
function get_next_stage(rng, ::Val{Egg}, ::Val{Female}, _)
    stage_cd = randt(rng, Int16, CD_F_ADULT)
    return Nymph, stage_cd
end
function get_next_stage(rng, ::Val{Nymph}, ::Val{Male}, _)
    stage_cd = randt(rng, Int16, CD_M_DEATH)
    return Adult, stage_cd
end
function get_next_stage(rng, ::Val{Nymph}, ::Val{Female}, ::Val{Macro})
    stage_cd = randt(rng, Int16, CD_F_M_DEATH)
    return Adult, stage_cd
end
function get_next_stage(rng, ::Val{Nymph}, ::Val{Female}, ::Val{Brachy})
    stage_cd = randt(rng, Int16, CD_F_B_DEATH)
    return Adult, stage_cd
end
function get_next_stage(_, ::Val{Adult}, _, _)
    return Dead, 9999
end
function get_next_stage(rng, stage::Stage, gender::Gender, form::Form)
    get_next_stage(rng, Val(stage), Val(gender), Val(form))
end

#
# Agent actions: grow up, move, eat, reproduce and die
#
"""
    agent_action_growup!(agent, model)

Perform the grow up action on `agent`:

1. The stage cooldown of the agent is decresed by one.
2. The agent consumes energy.
3. If stage cooldown is greater than zero, end the action.
4. Otherwise, get the next stage and sample the next stage cooldown,
    assign the stage and cooldown to the agent.
"""
function agent_action_growup!(agent, model)
    agent.stage_cd -= 1
    agent.energy = agent.energy - model.energy_consume
    @return_if agent.stage_cd > 0
    stage, stage_cd = get_next_stage(model.rng,
                                     agent.stage,
                                     agent.gender,
                                     agent.form)
    agent.stage = stage
    agent.stage_cd = stage_cd
end

@doc raw"""
    agent_action_move!(agent, model)

Perform the move action of the `agent`:

- Check the conditions, either:
    - energy is greater or equal to energy consumption,
    - rice at current position is zero,
    - the cell type is flower,
If the condition is not satisfied, stop the action,
- The agent consumes energy,
- Get all the directions within 2 cells (approx 30cm),
- Assign each direction ``\text{d}x, \text{d}y`` to a weight, the weight is calculated by
```math
w_{\text{d}x,\text{d}y}=\begin{cases}
e_{x+\text{d}x,y+\text{d}y}, & x+\text{d}x,y+\text{d}y\text{ is rice cell},\\
0.5, & \text{otherwise}
\end{cases}
```
where ``x, y`` is the position of `agent` on the grid, ``e_{\cdot,\cdot}`` is the rice cell energy.
- Perform weighted sampling on the directions to select one direction.
- The agent move along the sampled direction.
"""
function agent_action_move!(agent, model)
    x, y = agent.pos

    # Stay and eat if low energy
    @return_if agent.energy < model.energy_consume && (model.rice_map[x, y] > 0) &&
               model.cell_types[x, y] == RiceCell

    # Energy lost due to action
    agent.energy = agent.energy - model.energy_consume

    # Sample a direction base on food
    rng = model.rng
    rice_map = model.rice_map
    cell_types = model.cell_types
    directions = shuffle!(rng, model.moving_directions)
    direction_weights = map(directions) do (dx, dy)
        x2, y2 = (x + dx, y + dy)
        rice = get(rice_map, (x2, y2), -Inf32)
        cell_type = get(cell_types, (x2, y2), RiceCell)
        weight = (cell_type == FlowerCell) ? 0.5f0 : rice
        weight = weight + (dx == 0) * (dy == 0) * (rice + -Inf32 * (rice == 0))
        return weight
    end
    dx, dy = wsample(rng, directions, Weights(direction_weights))

    walk!(agent, (dx, dy), model)
end

function agent_action_eat!(agent, model)
    x, y = agent.pos
    @return_if model.cell_types[x, y] == FlowerCell

    # Self cap
    transfer = min(model.parameters.energy_transfer,
                   1 - agent.energy)

    # Environment cap
    transfer = min(transfer, model.rice_map[x, y])

    # Action cost
    transfer = transfer - model.energy_consume

    # Eat
    model.rice_map[x, y] -= transfer
    agent.energy += transfer
end

function agent_action_reproduce!(agent, model)
    agent.reproduction_cd = agent.reproduction_cd - 1
    @return_if agent.gender == Male
    @return_if agent.energy < model.energy_consume
    @return_if agent.reproduction_cd > 0
    @return_if model.rice_map[agent.pos...] <= model.parameters.energy_transfer

    # 
    # Reproduction
    #
    rng = model.rng
    num_offsprings = trunc(Int, rand(rng, DST_NUM_OFFSPRINGS))
    for _ in 1:num_offsprings
        id = nextid(model)
        energy = agent.energy # copy from parent energy
        pos = agent.pos
        stage = Egg
        stage_cd = trunc(Int, rand(rng, CD_NYMPH))
        gender = wsample(rng, GENDERS, GENDER_DST)
        form = wsample(rng, FORMS, FORM_DST)
        reproduction_cd = trunc(Int, rand(rng, REPRODUCE_1ST_CDS[form]))
        offspring = BPH(; id, energy, pos, stage, stage_cd, form, gender, reproduction_cd)
        add_agent_pos!(offspring, model)
    end

    #
    # Reset reproduction cooldown
    #
    agent.reproduction_cd = trunc(Int, rand(rng, REPRODUCE_CDS[agent.form]))

    #
    # Energy loss from reproduction
    #
    agent.energy = agent.energy - model.energy_consume
end

function agent_action_die!(agent, model)
    if agent.energy <= 0 || agent.stage == Dead
        remove_agent!(agent, model)
    end
end

#
# Agent steps by age stages
#
"""
    agent_step_egg!(agent, model)

The eggs have the following actions (performed in order):
- [`agent_action_growup!`](@ref)
- die
"""
function agent_step_egg!(agent, model)
    agent_action_growup!(agent, model)
    agent_action_die!(agent, model)
end

"""
    agent_step_nymph!(agent, model)

The nymphs have the following actions (performed in order):
- [`agent_action_growup!`](@ref)
- [`agent_action_move!`](@ref)
- eat
- die
"""
function agent_step_nymph!(agent, model)
    agent_action_growup!(agent, model)
    agent_action_move!(agent, model)
    agent_action_eat!(agent, model)
    agent_action_die!(agent, model)
end

"""
    agent_step_adult!(agent, model)

The adult BPHs have the following actions (performed in order):
- [`agent_action_growup!`](@ref)
- [`agent_action_move!`](@ref)
- eat
- reproduce
- die
"""
function agent_step_adult!(agent, model)
    agent_action_growup!(agent, model)
    agent_action_move!(agent, model)
    agent_action_eat!(agent, model)
    agent_action_reproduce!(agent, model)
    agent_action_die!(agent, model)
end

const STEPS = Dict(Egg => agent_step_egg!,
                   Nymph => agent_step_nymph!,
                   Adult => agent_step_adult!)

#
# Agent step entry point function
#
"""
    agent_step!(agent, model)

Perform agent actions in step, actions are determined by their stages.
Each stage's actions is defined in its respective step function.

- eggs: [`agent_step_egg!`](@ref)
- nymphs: [`agent_step_nymph!`](@ref)
- adults: [`agent_step_adult!`](@ref)
"""
function agent_step!(agent, model)
    step_fn! = STEPS[agent.stage]
    step_fn!(agent, model)
end
