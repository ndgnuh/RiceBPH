module Experiments

# Env libs
using Distributed
using Configurations
using Comonicon
using InteractiveDynamics
using ProgressMeter
using JDF

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
