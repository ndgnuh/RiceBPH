using Base: @kwdef
using Agents: AbstractAgent

"""
Model input variables.
"""
@kwdef struct ModelParameters
    # Initialization parameters
    map_size::Int
    flower_width::Int
    num_init_bphs::Int
    init_pr_eliminate::Float32
    init_position::InitPosition = Corner
    energy_transfer::Float32 = 0.1f0
end

"""
Model properties. There are two types of properties:
- The first types are properties that are inferred from the input variables to be used during the simulation.
- The second types are properties to collect statistics during the simulations.

Properties (except `num_rice_cells`) those are used to collect model statistics has the name prefix 
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
