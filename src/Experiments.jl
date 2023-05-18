module Experiments

# Env libs
using Distributed
using Configurations
using Comonicon
using InteractiveDynamics
using ProgressMeter
using JDF
using GLMakie
using DataFrames
using StatsBase

# Local libs
using ..Models
using ..Visualisations
using ..Results
using ..Utils

include("Experiments/plot_config.jl")
include("Experiments/config.jl")

include("Experiments/plot_run.jl")
include("Experiments/run.jl")

@main function main(; config::RunConfig)
    @info "Detected configuration of type $(typeof(config.config))"
    run(config.config)
end

end
