using Base: @kwdef
using Agents: AbstractAgent

@kwdef struct ModelParameters
    # Initialization parameters
    map_size::Int
    flower_width::Int
    num_init_bphs::Int
    init_pr_eliminate::Float32
    init_position::InitPosition = Corner

    # Running paramters
    num_max_offsprings::Int8 = 12
    num_min_offsprings::Int8 = 5
    energy_transfer::Float32 = 0.1f0
end

@kwdef mutable struct ModelProperties
    parameters::ModelParameters
    rice_map::Matrix{Float32}
    pr_eliminate_map::Matrix{Float32}
    eliminate_positions::Vector{Tuple{Int, Int}}
    flower_mask::Matrix{Bool}
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
