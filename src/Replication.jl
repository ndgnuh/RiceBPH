module Replication

using Agents
using Distributed
using JLD2
@everywhere using ProgressMeter

"""
	generate_filename(prefix="")

Generate filename from list of parameters.
"""
function generate_filename(prefix=""; kwargs...)
    kwargs_str = [
        begin
            k = replace(string(k), r"[-_ ]" => "+")
            v = last(splitdir(string(v)))
            "{$(k)_$(v)}"
        end for (k, v) in kwargs
    ]
    if !isempty(prefix)
        kwargs_str = [prefix; kwargs_str...]
    end
    return join(kwargs_str, "_")
end

function replication(
    init_model::Function,
    agent_step!,
    model_step!,
    steps,
    n::Integer;
    post_process=(adf, mdf) -> (adf, mdf),
    seed_offset=0,
    adata,
    mdata,
    kwargs...,
)
    kwargs = Dict(kwargs)
    delete!(kwargs, :seed)
    models = ([seed => init_model(; seed=seed + seed_offset, kwargs...) for seed in 1:n])
    data = @showprogress pmap(models) do (seed, model)
        adf, mdf = run!(model, agent_step!, model_step!, steps; adata=adata, mdata=mdata)
        df = post_process(adf, mdf)
        seed => df
    end
    return Dict(data)
end

end
