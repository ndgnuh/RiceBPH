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
# Agent actions: grow up, move, eat, reproduce and die
#
@doc raw"""
    agent_action_growup!(agent, model)

Perform the grow up action on agent with id ``i``:

The stage countdown of the agent is decresed by one.
```math
\begin{equation}
t_i^{\prime(s)} = t_i^{(s)} - 1.
\end{equation}
```
The agent then consumes energy.
```math
e_i' = e_i - E_C
```
If stage countdown is greater than zero, end the action. Otherwise, get the next stage and sample the next stage countdown, assign the next stage and the next countdown to the agent.
The next stage  ``z^{\prime(s)}_i`` and next the stage countdown ``t^{\prime(s)}_i`` is returned by [`get_next_stage`](@ref).
"""
function agent_action_growup!(agent, model)
    agent.stage_cd -= 1
    agent.energy = agent.energy - model.energy_consume
    @return_if agent.stage_cd > 0
    #
    # transit to next stage
    #
    agent.stage = get_next_stage(agent.stage)

    #
    # Assign new stage cooldown
    #
    stage_cd_dist = get_stage_countdown(agent.stage, agent.gender, agent.form)
    agent.stage_cd = trunc(Int16, rand(model.rng, stage_cd_dist))
end

@doc raw"""
    agent_action_move!(agent, model)

Perform the move action of the `agent`:

Let the agent's ID ``i``, the agent's position on the grid ``x=x_i``, ``y=y_i``. The agent only moves under certain conditions, either: energy is greater or equal to energy consumption
```math
\begin{equation}
e_i \ge E_T;
\end{equation}
```
or the cell that the agent is currently on is a rice cell and has zero energy:
```math
\begin{equation}
e_{x, y} = 0;
\end{equation}
```
or the cell type is flower:
```math
\begin{equation}
t_{x, y} = 0.
\end{equation}
```
If the condition is not satisfied, stop the action.
Otherwise, the agent then consume energy:
```math
\begin{equation}
e_{i}'= e_{i} - E_C.
\end{equation}
```
After that, a direction ``\text{d}x, \text{d}y`` is sampled within the radius of 2 cells (approximately 30cm) with weights.
The weight of the moving direction is calculated by
```math
\begin{equation}
w_{\text{d}x,\text{d}y}=\begin{cases}
e_{x+\text{d}x,y+\text{d}y}, & t_{x+\text{d}x,y+\text{d}y}=1,\\
0.5, & t_{x+\text{d}x,y+\text{d}y}=0.
\end{cases}
\end{equation}
```
After a direction is sampled, the agent then move along the sampled direction
```math
\begin{align}
x'_i &= x_i + \text{d}x,\\
y'_i &= y_i + \text{d}y.
\end{align}
```
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

@doc raw"""
    agent_action_eat!(agent, model)

Perform eat action of `agent`.

First, check if the current cell is a [`FlowerCell`](@ref), if it is, stop the action.

An amount of energy is subtracted from the [`RiceCell`](@ref) ``x_i,y_i`` and added to the agent ``i``.
```math
\begin{align}
e'_{x_i, y_i} &= e_{x_i,y_i} - \text{d} e,\\
e'_i &= e_i + \text{d} e,
\end{align}
```
where the transfered energy ``\text{d}e`` is calculated by
```math
\begin{equation}
\text{d} e=\min\left(1-e_i,e_{x_i,y_i},e_{T}\right).
\end{equation}
```
"""
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

@doc raw"""
    agent_action_reproduce!(agent, model)

Perform the reproductive action of `agent` ``i``.

First, decrease the reproduction countdown of the agent ``i``.
```math
\begin{equation}
t^{(p)'}_i = t^{(p)}_i - 1
\end{equation}
```
After that, check for the reproduction conditions: the `agent` is a female,
```math
\begin{equation}
z^{(g)}_i = 1,
\end{equation}
```
the agent energy is larger or equals than the energy consumption
```math
\begin{equation}
e_i \ge E_C,
\end{equation}
```
the reproduction countdown is zero:
```math
t^{(p)\prime} = 0,
```
the energy of rice cell at agent position is greater than the energy transfer parameter:
```math
e_{x_i, y_i} \ge E_T.
```
"""*"""
If the condition is met, the number of offsprings ``N`` from the distributions of offspring quantity $(show_dist(DST_NUM_OFFSPRINGS)).

TODO:
"""
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
        dist = get_preoviposition_countdown(form)
        reproduction_cd = trunc(Int, rand(rng, dist))
        offspring = BPH(; id, energy, pos, stage, stage_cd, form, gender, reproduction_cd)
        add_agent_pos!(offspring, model)
    end

    #
    # Reset reproduction countdown
    #
    let dist = get_reproduction_countdown(agent.form)
        agent.reproduction_cd = trunc(Int, rand(rng, dist))
    end

    #
    # Energy loss from reproduction
    #
    agent.energy = agent.energy - model.energy_consume
end

"""
    agent_action_die!(agent, model)

Check if the `agent` should be eliminated from the simulation.

The condition of elimination is either:
- The agent energy is zero or less,
- The agent is adult stage and their stage countdown is zero or less (`agent.stage == Dead`, see also [`Stage`](@ref))
"""
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
- [`agent_action_die!`](@ref)
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
- [`agent_action_eat!`](@ref)
- [`agent_action_die!`](@ref)
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
- [`agent_action_eat!`](@ref)
- [`agent_action_reproduce!`](@ref)
- [`agent_action_die!`](@ref)
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
