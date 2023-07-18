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
using Chain

# Local libs
using ..Models
using ..Visualisations
using ..Results
using ..Utils

function run_multi_configurations(configurations)
   outputdir = mktempdir()
   @info "intermediate result will be saved to $outputdir"

   result_files = @showprogress pmap(
      enumerate(configurations)
   ) do (i, params)
      outputfile = joinpath(outputdir, string(hash(params)))

      # Initialize and run the model
      model = M.init_model(; params...)
      mdf = M.run_ricebph!(model)

      # Compress and store intermediate result
      type_compress!(mdf; compress_float = true)
      savejdf(outputfile, mdf)

      # GC 
      if i == 20
         @everywhere GC.gc(false)
      end
      return outputfile
   end

   # Concat intermediate result and return the final one
   return mapreduce(vcat, result_files) do file
      DataFrame(JDF.loadjdf(file))
   end
end

include("Experiments/plot_config.jl")
include("Experiments/config.jl")

include("Experiments/plot_run.jl")
include("Experiments/run.jl")
include("Experiments/sobol.jl")
include("Experiments/presets.jl")

function Base.run(config::RunConfig)
   if config.config isa Vector
      @info "Detected configurations of type $(eltype(config.config))"
      for (i, cfg) in enumerate(config.config)
         @info "Running config #$(i)"
         run(cfg)
      end
   else
      @info "Detected configuration of type $(typeof(config.config))"
      run(config.config)
   end
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
   Base.run(config)
   #= end =#
end

end
