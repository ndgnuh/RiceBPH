module RiceBPH

include("Model.jl")
include("visualize.jl")
include("postprocess.jl")

using .Model: AGENT_DATA, MODEL_DATA, init_model
using GLMakie
using InteractiveDynamics

export Model, abmplot, GLMakie,
       AGENT_DATA, MODEL_DATA, init_model

end # module RiceBPH
