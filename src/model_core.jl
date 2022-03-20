using Base: @kwdef
using Agents
using Agents.Schedulers: by_id

@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float16
    age::Int
    isfemale::Bool
    isshortwing::Bool
end

function initialize(; kwargs...)
    params = InputParams(kwargs...)
    return initialize(params)
end

function initialize(params, seed::Int)
    space = GridSpace(size(food); periodic=false)
    scheduler = by_id
    properties = to_model_properties(params)
    model = ABM(BPH, space;
                scheduler=by_id,
                properties=properties,
                rng=rng)
    return model
end
