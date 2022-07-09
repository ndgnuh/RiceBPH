module Models

using Random
using Agents
using Base: @kwdef
using Base.Iterators

"""
    get_moving_directions(speed::Integer)

Return a set of tuples of integers, which are the moving directions.
The input `speed` must be non-negative.
"""
function get_moving_directions(speed::Integer)
    @assert speed >= 0
    speeds = product((-speed):speed, (-speed):speed)
    directions = [(i, j) for (i, j) in speeds
                  if abs(i) + abs(j) == speed]
    return Set(directions)
end

"""
    BPH{IntType,FloatType}(; keyword_parameters...)

The BPH agent.

## Keyword Parameters

- id: agent identifier
- pos: agent initial position
- engergy: agent initial energy
- age: agent initial age
- is_female: agent gender
- is_shortwing: agent form
"""
Base.@kwdef mutable struct BPH{IntType,FloatType} <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::FloatType
    age::IntType
    is_female::Bool
    is_shortwing::Bool
end

# END MODULE
end
