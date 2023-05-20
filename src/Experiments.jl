module Experiments

# Env libs
using Base: explicit_manifest_deps_get
using Distributed
using Configurations
using Comonicon
using InteractiveDynamics
using ProgressMeter
using JDF
using GLMakie
using DataFrames
using StatsBase
using TOML

# Local libs
using ..Models
using ..Visualisations
using ..Results
using ..Utils

include("Experiments/plot_config.jl")
include("Experiments/config.jl")

include("Experiments/plot_run.jl")
include("Experiments/run.jl")

function run(configs::Vector{T}) where {T <: SupportedConfig}
    run.(configs)
end

function run(config::RunConfig)
    @info "Detected configuration of type $(typeof(config.config))"
    run(config.config)
end

@main function main(config_file::String)
    config_toml = TOML.parsefile(config_file)
    #= if isa(config_toml["config"], Vector) =#
    #=     for _config in config_toml["config"] =#
    #=         config = from_kwargs(RunConfig, config = _config) =#
    #=         run(config) =#
    #=     end =#
    #= else =#
    config = from_dict(RunConfig, config_toml)
    run(config)
    #= end =#
end

end