module Experiments

# Env libs
using Configurations
using Comonicon
using InteractiveDynamics
using ProgressMeter

# Local libs
using ..Models
using ..Visualisations

include("Experiments/config.jl")
include("Experiments/run.jl")


@main function main(; config::RunConfig)
    @info "Detected configuration of type $(typeof(config.config))"
    run(config.config)
end

end
