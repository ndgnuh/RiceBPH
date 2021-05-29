module Replication

using Agents
using Distributed
using JLD2

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
    adata,
    mdata,
    kwargs...,
)
    kwargs = Dict(kwargs)
    delete!(kwargs, :seed)
    models = [init_model(; seed=seed, kwargs...) for seed in 1:n]
    data = pmap(enumerate(models)) do (seed, model)
        adf, mdf = run!(model, agent_step!, model_step!, steps; adata=adata, mdata=mdata)
        seed => post_process(adf, mdf)
    end
    filename = generate_filename(; kwargs...)
    jldopen(filename) do f
        f["metadata"] = kwargs
        for (seed, df) in data
            f[seed] = df
        end
    end
    return data
end

end
