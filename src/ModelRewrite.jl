module Models

using Reexport
using Agents

include("modeling/utils.jl")
include("modeling/constants.jl")
include("modeling/mapping.jl")
include("modeling/structs.jl")
include("modeling/init.jl")
include("modeling/agent_step.jl")
include("modeling/model_step.jl")

function run_ricebph!(model; num_steps=2880, mdata=MDATA)
    _, mdf = run!(model, agent_step!, model_step!, num_steps; mdata)
    return mdf
end

export init_model, agent_step!, model_step!, run!, MDATA, run_ricebph!

end
