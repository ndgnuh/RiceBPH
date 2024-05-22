import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using RiceBPH
using RiceBPH.Visualisations
using Agents
using GLMakie
using Comonicon

@main function main(;
   init_position::String = "corner",
   init_pr_eliminate::Float32 = 0.0f0,
   map_size::Int = 125,
   flower_width::Int = 0,
   energy_transfer::Float32 = 0.032f0,
   init_num_bphs::Int = 200,
   seed::Int = 0,
)
   GLMakie.activate!()

   # Enum parse
   init_position_enum = if init_position == "corner"
      RiceBPH.Models.Corner
   else
      RiceBPH.Models.Border
   end

   model = RiceBPH.Models.init_model(;
      init_position = init_position_enum,
      init_pr_eliminate = init_pr_eliminate,
      flower_width = flower_width,
      map_size = map_size,
      init_num_bphs = init_num_bphs,
      energy_transfer = energy_transfer,
      seed = seed,
   )
   fig, _ = abmexploration(
      model;
      RiceBPH.Models.agent_step!,
      RiceBPH.Models.model_step!,
      mdata = RiceBPH.Models.MDATA_EXPL,
      Visualisations.ac,
      Visualisations.heatkwargs,
      Visualisations.heatarray,
   )
   scene = display(fig)
   wait(scene)
end
