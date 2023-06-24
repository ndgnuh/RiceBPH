using Statistics

"""
    model_step!(model)

Model behaviour in one step, which includes:

  - `model_action_eliminate!`
  - `model_action_summarize!`
"""
function model_step!(model)
   model_action_eliminate!(model)
   model_action_summarize!(model)
end

@doc raw"""
    model_action_summarize!(model)

Collect agent and rice statistics and save them in model properties.
The collected is the percentage of healthy rice ``r_R`` and the number of BPHs, matching stages, forms and genders.

Metric  | Description
:---    | :---
``r_R`` | Percentage of healthy rice
``n_E`` | Number of eggs
``n_N`` | Number of nymphs
``n_M`` | Number of adults with fully-winged form
``n_B`` | Number of adults with truncate-winged form
``n_B`` | Number of females

These metrics are calculated as follow:
```math
\begin{align}
r_{R} & =\frac{\left|\left\{ \left(x,y\right)\colon t_{x,y}=1\land e_{x,y}\ge0.5\right\} \right|}{\left|\left\{ \left(x,y\right)\colon t_{x,y}=1\right\} \right|}\\
n_{E} & =\left|\left\{ i\colon z_{i}^{\left(s\right)}=0\right\} \right|,\\
n_{N} & =\left|\left\{ i\colon z_{i}^{\left(s\right)}=1\right\} \right|,\\
n_{M} & =\left|\left\{ i\colon z_{i}^{\left(s\right)}=2\land z_{i}^{\left(t\right)}=0\right\} \right|,\\
n_{B} & =\left|\left\{ i\colon z_{i}^{\left(s\right)}=2\land z_{i}^{\left(t\right)}=1\right\} \right|,\\
n_{F} & =\left|\left\{ i\colon z_{i}^{\left(s\right)}\ne0\land z_{i}^{\left(g\right)}=1\right\} \right|.
\end{align}
```
"""
function model_action_summarize!(model)
   #
   # Percentage of total rice energy
   #
   rice_map = model.rice_map
   num_heathy_rice_cells =
      count(model.rice_positions) do idx
         rice_map[idx] >= 0.5f0
      end
   pct_rices = num_heathy_rice_cells / model.num_rice_cells

   #
   # Collect BPH population statistics
   #
   num_eggs = 0
   num_nymphs = 0
   num_macros = 0
   num_brachys = 0
   num_females = 0
   for (_, agent) in (model.agents)
      stage = agent.stage
      if agent.gender == Female && stage != Egg
         num_females = num_females + 1
      end
      if stage == Egg
         num_eggs += 1
      elseif stage == Nymph
         num_nymphs += 1
      elseif agent.form == Brachy
         num_brachys += 1
      else
         num_macros += 1
      end
   end

   #
   # Save statistics
   #
   model.num_eggs = num_eggs
   model.num_nymphs = num_nymphs
   model.num_macros = num_macros
   model.num_brachys = num_brachys
   model.num_females = num_females
   model.pct_rices = pct_rices
end

const LOG_OF_2 = log(2.0f0)

@doc raw"""
    model_action_eliminate!(model)

Eliminate BPHs base on their energy and the pr eliminate map.
The elimination probability is given by  ``p_{x,y}``.

For each position ``x, y``, for each agent ``i`` whose position ``x_i = x, y_i = y``, the agent is removed from the simulation with the probability ``p_{x, y}``.
"""
function model_action_eliminate!(model)
   for pos::Tuple in model.eliminate_positions
      aip = agents_in_position(pos, model)

      dist = Geometric(model.pr_eliminate_map[pos...])
      count = 0
      for agent in aip
         pr = pdf(dist, count)
         if rand(model.rng, Float32) < pr
            remove_agent!(agent, model)
            count = count + 1
         end
      end
   end
end
