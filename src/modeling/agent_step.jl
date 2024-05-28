using Random
using ..Utils: @return_if

#
# Agent actions: grow up, move, eat, reproduce and die
#
@doc raw"""
    agent_action_growup!(agent, model)

Perform the grow up action on agent with id ``i``:

The stage countdown of the agent is decresed by one.
```math
\begin{equation}
t_i^{(s)} \gets t_i^{(s)} - 1.
\end{equation}
```
The agent then consumes energy.
```math
e_i \gets e_i - E_C
```
If stage countdown is greater than zero, end the action. Otherwise, get the next stage and sample the next stage countdown, assign the next stage and the next countdown to the agent.
The next stage  ``z^{(s)}_i`` and next the stage countdown ``t^{(s)}_i`` is returned by [`get_next_stage`](@ref).
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

Let the agent's ID ``i``, the agent's position on the grid ``x=x_i``, ``y=y_i``. The agent only moves under certain conditions, which are: energy is greater or equal to energy consumption
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
If the conditions are not met, stop the action.
Otherwise, the agent then consumes energy:
```math
\begin{equation}
e_{i} \gets e_{i} - E_C.
\end{equation}
```
After that, a direction ``\Delta x, \Delta y`` is sampled within the radius of 2 cells (approximately 30cm) with weights.
The weight of the moving direction is calculated by
```math
\begin{equation}
w_{\Delta x,\Delta y}=\begin{cases}
e_{x+\Delta x,y+\Delta y}, & t_{x+\Delta x,y+\Delta y}=1,\\
0.5, & t_{x+\Delta x,y+\Delta y}=0.
\end{cases}
\end{equation}
```
After a direction is sampled, the agent then moves along the sampled direction
```math
\begin{align}
x_i &\gets x_i + \Delta x,\\
y_i &\gets y_i + \Delta y.
\end{align}
```
"""
function agent_action_move!(agent, model)
   x, y = agent.pos

   # Stay and eat if low energy
   @return_if agent.energy < model.energy_consume &&
      (model.rice_map[x, y] > 0) &&
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
e_{x_i, y_i} &\gets e_{x_i,y_i} - \Delta  e,\\
e_i &\gets e_i + \Delta  e,
\end{align}
```
where the transfered energy ``\Delta e`` is calculated by
```math
\begin{equation}
\Delta  e=\min\left(1-e_i,e_{x_i,y_i},e_{T}\right).
\end{equation}
```
"""
function agent_action_eat!(agent, model)
   x, y = agent.pos
   @return_if model.cell_types[x, y] == FlowerCell

   # Self cap
   transfer = min(model.parameters.energy_transfer, 1 - agent.energy)

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
t^{(p)}_i \gets t^{(p)}_i - 1
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
t^{(p)} = 0,
```
the energy of rice cell at agent position is greater than the energy transfer parameter:
```math
e_{x_i, y_i} \ge E_T.
```
""" *
   """
If the condition is met, the number of offsprings ``N`` from the distributions of offspring quantity $(show_dist(DST_NUM_OFFSPRINGS)).

For ``k=\\overline{1, N}``, the offspring agent ``k`` is initialized with:
- energy the same as their parent: ``e_k \\gets e_i``,
- the position of the parent ``x_k \\gets x_i``, ``y_k \\gets y_i``,
- stage is egg: ``z^{(s)}_k \\gets $(Int(Egg))``,
- stage countdown is of egg: ``t^{(s)}_k \\gets ``$(show_dist(CD_NYMPH)),
- gender ``z^{(g)}_k``: sample from $(show_enum(Gender)) with weight $(show_dist(GENDER_DST)),
- form ``z^{(f)}_k``: sample from $(show_enum(Form)) with weight $(show_dist(FORM_DST)),
- reproduction countdown follows the preoviposition distribution (which depends on the form).
The reproduction countdown is initialized with preoviposition so that when the agent's reproduction is enabled, it automatically enters the preoviposition.

After reproducing, the mother agent ``i`` consume energy and get a new reproduction count down:
""" *
   raw"""
```math
\begin{align}
t_{i}^{\left(r\right)} &\gets t^{\left(r\right)}\left(z_{i}^{\left(f\right)}\right),\\
e_{i} &\gets e_{i}-E_{C}.
\end{align}
```

See also: [`get_preoviposition_countdown`](@ref), [`get_reproduction_countdown`](@ref).
""" function agent_action_reproduce!(agent, model)
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
      offspring = BPH(;
         id, energy, pos, stage, stage_cd, form, gender, reproduction_cd
      )
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

The agent ``i`` dies and gets removed from the simulated if either: its energy is zero or less (``e_i \\le 0``), or its stage is "Dead" (``z^{(s)}_i = $(Int(Dead))``).

See also: [`Stage`](@ref).
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
agent_step!(agent, model) = agent_step!(agent, model, Val(agent.stage))
agent_step!(agent, model, ::Val{Egg}) = agent_step_egg!(agent, model)
agent_step!(agent, model, ::Val{Nymph}) = agent_step_nymph!(agent, model)
agent_step!(agent, model, ::Val{Adult}) = agent_step_adult!(agent, model)
