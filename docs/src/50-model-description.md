```@setup
using RiceBPH
```

# Model description

## Purpose and pattern

This model has two purposes, the first is to build a stable model for BPH population.
The second is to research the effectiveness of cultivated flower
in preventing the dispersion of BPH and providing a rough guideline 
on how flowers should be planted to effectively prevent the BPH from spreading 
and still, ensure economic benefit for the farmers.

To verify the stability and trustiness of the model, we use population structure and patterns from [Syahrawati2019]() as a pattern for verifying our model.

## Entities, state variables, and scales

### Entities and state variables

Our model contains two types of entities.

The first type of entity is the BPH. Each is associated with, energy, a stage, gender, and type. The BPH has a truncate-winged form Brachypterous and a fully-winged form Macropterous. The Brachypterous variant moves slowly and has a high reproduction rate, while the other has the opposite specifications.
We also employ a countdown-based system to model the reproduction and growth of BPHs.

Variable      | Description                                                 | Value(s)
:---          | :---                                                        | :---
``i``         | The agent identifier number                                 | ``1, 2, \ldots``
``x_i``       | The ``x``-coordinate of agent ``i`` on the environment grid | ``1, 2, \ldots S``
``y_i``       | The ``y``-coordinate of agent ``i`` on the environment grid | ``1, 2, \ldots S``
``z^{(g)}_i`` | The gender of agent ``i`` (male, female)                    | ``0, 1``
``z^{(s)}_i`` | The current stage of agent ``i`` (egg, nymph, adult, dead)  | ``0, 1, 2, 3``
``z^{(f)}_i`` | The form of agent ``i`` (brachypterous, macropterous)       | ``0, 1``
``t^{(s)}_i`` | The countdown to the next stage of agent ``i``              | ``0, 1,\ldots``
``t^{(r)}_i`` | The countdown to the next reproduction of agent ``i``       | ``0, 1,\ldots``

The second type of entity is the environment (grid) cell.
An environment cell can plant rice or cultivated flower. 
Rice cells have living energy while flower cells do not. 
But for the sake of simplicity, we model them in one entity and have the flower cells ignore the energy.
All cells have an elimination probability, which is the probability that the BPH on that cell will be eliminated.
The cultivated flowers do not directly eliminate the BPH, they attract their natural enemies (such as bees).
The natural enemies wander around, therefore every cell has an elimination probability.

!!! info
	Since we use Julia's matrices to represent the simulated environment, there is no such thing as a `GridCell` type with all the described state variable in the implementation. These state variables are written is this way for the sake of model description.

Variable     | Description                                         | Value(s)
:---         | :---                                                | :---
``x``        | The cell's ``x``-coordinate on the environment grid | ``1, 2,\ldots,S``
``y``        | The cell's ``y``-coordinate on the environment grid | ``1, 2,\ldots,S``
``t_{x, y}`` | The type of the cell at ``x, y`` (flower, rice)     | ``0, 1``
``e_{x, y}`` | The energy of the cell at ``x, y``                  | ``[0, 1]``
``p_{x, y}`` | The elimination probability of the cell at ``x, y`` | ``[0, P_0]``

### Scales

Regarding the scales of the model, we use a discrete space scale.
The total simulated environment is equivalent to a $360\mathrm{m^2}$ rice field.
The field is divided into $125\times125$ grid cells;
i.e. each cell's width is roughly equivalent to $0.15\mathrm{m}$ real world length.

Time is also represented discretely in the model.
Each time step is equivalent to one actual hour. 
The total duration of the simulation is $2880$ steps, or $120$ days,
equivalent to a crop cycle.

## Process overview and scheduling

### Scheduling
In each step of the simulation, the BPH agents execute their processes and 
then the environment cells do theirs.
The BPH agents with higher energy perform their actions first.

### The vegetation cells process

The environment only has one action, which is to eliminate the BPHs.
This action does not apply if there is no flower planted.

### The BPH agents processes

The agent actions are determined by their stages, each stage have different behaviours.
```@docs
RiceBPH.Models.agent_step_egg!
RiceBPH.Models.agent_step_nymph!
RiceBPH.Models.agent_step_adult!
```

## Design Concepts

### Basic principle

The model is based on a natural real-life phenomenon called "hopper burn",
where a small infestation of BPH spreads out and destroys the whole rice field.

We model bio-conversion using energy. 
The energy is used to measure how well an agent is living. 
The energy accepts values ranging from zero to one.
When an agent's energy goes to zero, it dies and gets removed from the simulation.
Both entities have their energy scaled to $0$ and $1$ and there is a conversion
parameter to represent the relative energy scale between them.

The flower grid cells are simulations of real-life cultivating flowers.
The flowers invite the BPH's natural enemies to eliminate them. 
We emulate this with an elimination probability map on the whole field.
Each cell has a probability that: if a BPH is in that position, it might get eliminated.

### Emergence

At a high level, we observe the BPH population structure and
the overall healthiness of the rice field.

### Adaptation

The BPHs base their decisions on their
internal states and on the vegetation cell's type and energy.

The first input is their stage. Each stage links to specific actions.
For example, BPH eggs can not move around.
The second input is their countdowns.
Their actions are timed by their countdowns.
The third input is their energy.
Their actions have energy-based conditions.
The fourth input is the environment cell type and energy.
These factors affect their movement, eating, and reproduction.

### Prediction
The BPHs agent implicitly predicts the amount of food available.
Their prediction is presented in probabilities. 
Their movement distribution is calculated from environment energy states.
Their reproduction is also conditioned on the environment cell's energy.

### Sensing

The BPHs are able to sense their internal states.
They can also sense the energy and type of nearby cells to make predictions and decisions. 

### Interaction

There are one direct interaction and two indirect ones.

The direct one is that the BPHs feed off the cells with rice directly. 
The indirect interactions are:
- The cells eliminate the BPHs with the probability map. 
- The BPHs indirectly compete among themselves for food from the vegetation cells.

We consider the former interaction indirect because the probability map was just emulating the natural enemies, which is not modeled in our model.


### Stochasticity

Stochasticity is used in the model mainly for the diversity
of the results and to realistically model multi-option processes
and to simplify complicated phenomena.

The processes that use stochasticity are:
- initial placement and population structure of BPHs,
- the BPHs' growth,
- the BPHs' reproduction,
- the BPHs' movement.

For reproducibility, we use a controlled pseudo-random number generator
for all the stochastic processes in the model.

### Observation

During our experiment, we collect the following data:

- the percentage of healthy rice cells ``r_R``,
- the number of eggs ``n_E``,
- the number of nymphs ``n_N``,
- the number of adult macropterous ``n_M``,
- the number of adult brachypterous ``n_P``,
- the number of female nymphs and adults ``n_F``.

For the BPH-related data, we also calculate inferable data such as:
- the total number of BPHs (eggs are not counted) ``n_A``,
- the percentage of nymphs ``r_N``,
- the percentage of adult macropterous ``r_M``,
- the percentage of adult brachypterous ``r_P``,
- the ratio of females over males ``r_F``.

We collect these data at each time step of the simulation.
We use a function-like annotation to refer to the data point at a specific time step.
For example, the number of eggs at the time ``t`` is ``n_E(t)``.

## Initialisation

The initialization of the simulation includes several steps.
The first step is to calculate the model states and initialize vegetation cells.
The model state also creates a controlled random number generator.
The second step is to initialize the BPH agents and place them inside the model.
At the initialization of the model, we create the environment.

!!! warning
	TODO?

```@docs
RiceBPH.Models.init_model
```

## Input data
The model does not use any external data.

## Submodels

##### Notation
To make sure readers understand our model correctly, we will provide the notation system that we use in this material.

We use index variables such as ``i,j,k,l,\ldots`` to refer to the identification number of an agent.
The state variable of an agent is referred to by their respective notation in [Entities, state variables, and scales](@ref).
For example, the energy of agent ``i`` is ``e_i``.

For vegetation cells, we use spatial coordinates (such as ``x,y``) to index them.
Their state variables follow the same rule.
For example, the energy of the rice cell at position ``x, y`` is ``e_{x,y}``,
the energy of the rice cell where the agent ``i`` at is ``e_{x_i, y_i}``.

To abuse the notation, we hide the timestep variable and consider each submodel within its context (the "current" timestep).
The state variable is updated in-place and the update is notated by ``\gets``.
For example, when an agent consumes energy:
```math
e_i \gets e_i - E_C.
```
We do not explicitly refer to the timestep ``t`` for several reasons.
The main reason is that sometime, state variables are updated many times within a timestep, so it is not possible to use a timestep variable to describe the changes.
Moreover, every submodel is described in its own context, therefore, the current time step is always ``t``; adding the time step variable ``t`` does not make it easier to perceive the model (if not harder).


##### Model parameters
The initialisation variables, parameters and states of the model are presented in the next table:


Variable  | Description                                          | Value
:---:     | :---                                                 | ---:
``S``     | The environment grid size                            | ``125``
``S_F``   | The number of flower cells at the center of the grid | ``0``
``N_{I}`` | The number of initialized BPH                        | ``200``
``P_0``   | The base elimination probability                     | ``0``
-         | The BPHs' initial positions                          | [`Corner`](@ref)
``E_{T}`` | The energy conversion from rice to BPHs              | ``0.032``
``E_{C}`` | The energy conversion from rice to BPHs              | ``E_T / 3``

##### Initialisation actions

Since the vegetation cells are organized in a grid,
we use matrices to represent the cells for efficiency.
The coordinates of the vegetation cells translate directly to the matrix indices.
Each of the other states is represented by a matrix.
```@docs
RiceBPH.Models.init_cell_types
RiceBPH.Models.init_rice_map
RiceBPH.Models.init_pr_eliminate
RiceBPH.Models.init_bphs!
```

##### Vegetation cell submodels

```@docs
RiceBPH.Models.model_action_eliminate!
```

##### BPH agent submodels
```@docs
RiceBPH.Models.agent_action_growup!
RiceBPH.Models.agent_action_move!
RiceBPH.Models.agent_action_eat!
RiceBPH.Models.agent_action_reproduce!
RiceBPH.Models.agent_action_die!
```

##### Reproduction parameters

```@docs
RiceBPH.Models.Form
RiceBPH.Models.get_reproduction_countdown
RiceBPH.Models.get_preoviposition_countdown
```

##### Age structure

```@docs
RiceBPH.Models.Stage
RiceBPH.Models.get_stage_countdown
RiceBPH.Models.get_next_stage
```

##### Data collection


!!! danger
	This is unfinished documentation.

```@docs
RiceBPH.Models.model_action_summarize!
```


## Bibliography

```@bibliography
```
