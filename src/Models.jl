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

# END MODULE
end
