# Using include instead of `using`
# because of a bug in LSP
include("../src/RiceBPH.jl")

const OUTPUT_PATH = joinpath("outputs", "num-replications")
@info "Experiment outputs will be written to $(realpath(OUTPUT_PATH))"

using Printf
using Random
using ProgressMeter
using Agents
using DataFrames
using JDF
Model = RiceBPH.Models

# Typical parameter configuration that will have all the model features
const max_replications = 1000
const params = RiceBPH.Models.ModelParameters(;
   map_size = 125,
   flower_width = 10,
   init_num_bphs = 200,
   init_pr_eliminate = 0.1f0,
   energy_transfer = 0.032f0,
)

# Reproducible replication
const progress = Progress(max_replications)
const rng = Xoshiro(0)
for rep in 1:max_replications
   # Run simulation
   model::Agents.AgentBasedModel = RiceBPH.Models.init_model(params; rng = rng)
   df::DataFrame = RiceBPH.Models.run_ricebph!(model)

   # Save collected simulation data
   output::String = joinpath(OUTPUT_PATH, @sprintf "replication-%05i" rep)
   JDF.save(output, df)

   # Show information
   let showvalues = [
         (:replication, "$(rep)/$(max_replications)"),
         (:map_size, string(params.map_size)),
         (:flower_width, string(params.flower_width)),
         (:init_num_bphs, string(params.init_num_bphs)),
         (:init_pr_eliminate, string(params.init_pr_eliminate)),
         (:energy_transfer, string(params.energy_transfer)),
      ]
      next!(progress; showvalues = showvalues)
   end
end
