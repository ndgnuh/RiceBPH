using Base: @kwdef
using Agents: AbstractAgent

"""
`ModelParameters` contains initialization variables.

Variable            | Type                   | Default          | Description                                          | Symbol
:---                | :---                   | :---             | :---                                                 | :---
`map_size`          | `Int`                  | -                | The environment grid size                            | ``S``
`flower_width`      | `Int`                  | -                | The number of flower cells at the center of the grid | ``S_F``
`num_init_bphs`     | `Int`                  | -                | The number of initialized BPH                        | ``N_{I}``
`init_pr_eliminate` | `Float32`              | -                | The base elimination probability                     | ``P_0``
`init_position`     | [`InitPosition`](@ref) | [`Corner`](@ref) | The BPHs' initial positions                          | -
`energy_transfer`   | `Float32`              | `0.032`          | The energy conversion from rice to BPHs.             | ``E_T``
"""
@kwdef struct ModelParameters
    # Initialization parameters
    map_size::Int
    flower_width::Int
    num_init_bphs::Int
    init_pr_eliminate::Float32
    init_position::InitPosition = Corner
    energy_transfer::Float32 = 0.032f0
end

@doc raw"""
Model properties. There are three types of properties:
- Model state
- The first types are properties that are inferred from the input variables to be used during the simulation.
- The second types are properties to collect statistics during the simulations.

Properties (except `num_rice_cells`) those are used to collect model statistics has the name prefix .

##### Model states and inferable parameters:

Name                  | Type                                | Description                                                   | Symbol
:---                  | :---                                | :---                                                          | :---
`parameters`          | [`ModelParameters`](@ref)           | The initialisation parameter                                  | -
`rice_map`            | `Matrix{Float32}`                   | The matrix ``[e_{x,y}]_{s\times s}`` of rice cells' energy   | -
`pr_eliminate_map`    | `Matrix{Float32}`                   | The matrix of elimination probabilities at each grid position | -
`cell_types`          | [`Matrix{CellType}`](@ref CellType) | The matrix contains the cell type of each grid position       | -
`eliminate_positions` | `Vector{CartesianIndex}`            | Grid positions with elimination probability ``p_{x,y} > 0``   | -
`rice_positions`      | `Vector{CartesianIndex}`            | The positions of [`RiceCell`](@ref).                          | -
`num_rice_cells`      | `Int`                               | Total number of rice cells, equals to ``S^2``                 | -
`energy_consume`      | `Float32`                           | The energy consumption ``E_C`` of BPH agents                  | ``E_C``
`moving_directions`   | `Vector{Tuple{Int, Int}}`           | All the possible moving directions                            | -

The energy consumption ``E_C`` is calculated by dividing the energy transfer ``E_T`` to all the energy-consuming actions ([`agent_action_move!`](@ref), [`agent_action_reproduce!`](@ref), [`agent_action_growup!`](@ref)):
```math
\begin{equation}
E_C = \frac{E_T}{\mathrm{number of actions}} = \frac{E_T}{3}.
\begin{equation}
```

##### Statistics
These data are collected at each time step, see also [`model_action_summarize!`](@ref).

Name          | Type      | Description                                        | Symbol
:---          | :---      | :---                                               | :---
`pct_rices`   | `Float32` | Percentage of healty rice                          | ``r_{R}``
`num_eggs`    | `Int`     | Number of BPH eggs                                 | ``n_{E}``
`num_nymphs`  | `Int`     | Number of BPH in nymphs stage                      | ``n_{N}``
`num_brachys` | `Int`     | Number of BPH in adult stage, truncate-winged form | ``n_{B}``
`num_macros`  | `Int`     | Number of BPH in adult stage, fully-winged form    | ``n_{M}``
`num_females` | `Int`     | Number of female BPHs, counting nymphs and adults  | ``n_{F}``
"""
@kwdef mutable struct ModelProperties
    parameters::ModelParameters
    rice_map::Matrix{Float32}
    pr_eliminate_map::Matrix{Float32}
    eliminate_positions::Vector{Tuple{Int, Int}}
    rice_positions::Vector{CartesianIndex}
    num_rice_cells::Int
    cell_types::Matrix{CellType}
    energy_consume::Float32
    moving_directions::Vector{Tuple{Int, Int}}

    # Statistics
    pct_rices::Float32 = 1.0f0
    num_eggs::Int = 0
    num_nymphs::Int = 0
    num_brachys::Int = 0
    num_macros::Int = 0
    num_females::Int = 0
end

"""
The BPH agents, with the following state variables.

Variable | Type | Description 
:--- | :--- | :---
`id`| `Int` | The agent identifier number
`pos` | `Dims{2}` |  The agent's position on the environment grid
`energy` | `Float16` | The agent's energy
`gender` | [`Gender`](@ref) | The agent's gender
`form` | [`Form`](@ref) | The agent's form
`stage` | [`Stage`](@ref) | The agent's current stage
`stage_cd` | `Int16` | The countdown to agent's next stage
`reproduction_cd` | `Int16` | The countdown to agent's next reproduction
"""
@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float16
    gender::Gender
    form::Form
    stage::Stage
    stage_cd::Int16
    reproduction_cd::Int16
end
