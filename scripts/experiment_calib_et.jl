using Printf
using JDF
using ProgressMeter
using DataFrames
using Agents
using Random
import RiceBPH.Models as Models
#= include("../src/Ricce.jl") =#

# Experiment definition
const replications = 100
const output_dir = joinpath("..", "outputs", "calib_et")
const rng = Xoshiro(0)
const energy_transfers = begin
   X = range(0.005f0, 0.1f0; length = 20)
   collect(X)
end
const init_positions = [Models.Corner; Models.Border]
const base_params = Dict([
   :init_position => Models.Corner,
   :energy_transfer => 0.0f0,
   :map_size => 125,
   :flower_width => 0,
   :init_pr_eliminate => 0.0f0,
   :init_num_bphs => 200,
])

# Progress counter
const num_simulations =
   length(energy_transfers) * replications * length(init_positions)
const progress = Progress(num_simulations)
@info "Number of simulations $(num_simulations)"

# Grid search
const name_template = Printf.format"et-%.4f_pos-%s_rep-%03d"
simulation_count::Int = 0
for energy_transfer in energy_transfers,
   init_position in init_positions,
   replication in 1:replications
   # Generate parameter from base
   params = copy(base_params)
   params[:init_position] = init_position
   params[:energy_transfer] = energy_transfer

   # Result path
   output_name = Printf.format(
      name_template, energy_transfer, string(init_position), replication
   )
   output_path = joinpath(output_dir, lowercase(output_name))

   # Run simulation (cached)
   if !isdir(output_path)
      model = Models.init_model(; params...)
      df = Models.run_ricebph!(model)
   end

   # Save results
   type_compress!(df; compress_float = true)
   savejdf(output_path, df)

   # Update progress
   global simulation_count
   simulation_count = simulation_count + 1
   let
      replication_str = "$(replication)/$(replications)"
      simulation_count_str = "$(simulation_count)/$(num_simulations)"
      next!(
         progress;
         showvalues = [
            (:simulation_count, simulation_count_str),
            (:replication, replication_str),
            (:energy_transfer, energy_transfer),
            (:init_position, string(init_position)),
            (:simulation_output, output_path),
            (:all_energy_transfer, energy_transfers),
         ],
      )
   end
end
