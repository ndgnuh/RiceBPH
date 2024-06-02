module Models

using Reexport
using Agents
using DataFrames

include("modeling/utils.jl")
include("modeling/constants.jl")
include("modeling/mapping.jl")
include("modeling/structs.jl")
include("modeling/agent_step.jl")
include("modeling/model_step.jl")
include("modeling/init.jl")

const NUM_TOTAL_STEPS = 2880

function init_model_df()
   df = DataFrame()
   df.step = collect(1:NUM_TOTAL_STEPS)
   df.pct_rices = zeros(Float32, NUM_TOTAL_STEPS)
   df.num_nymphs = zeros(Float32, NUM_TOTAL_STEPS)
   df.num_eggs = zeros(Float32, NUM_TOTAL_STEPS)
   df.num_macros = zeros(Float32, NUM_TOTAL_STEPS)
   df.num_brachys = zeros(Float32, NUM_TOTAL_STEPS)
   df.num_females = zeros(Float32, NUM_TOTAL_STEPS)

   df.map_size = fill(Int32(125), NUM_TOTAL_STEPS)
   df.flower_width = fill(Int32(10), NUM_TOTAL_STEPS)
   df.init_num_bphs = fill(Int32(200), NUM_TOTAL_STEPS)
   df.init_pr_eliminate = fill(0.2f0, NUM_TOTAL_STEPS)
   df.energy_transfer = fill(0.03f0, NUM_TOTAL_STEPS)
   return df
end

function run_ricebph_v1!(model; num_steps = NUM_TOTAL_STEPS, mdata = MDATA)
   _, mdf = run!(model, num_steps; mdata)
   return mdf
end

function run_ricebph!(model; kwargs...)
   df = init_model_df()
   run_ricebph!(df, model; kwargs...)
end

function run_ricebph!(
   df::DataFrame, model; num_steps = NUM_TOTAL_STEPS, mdata = MDATA
)
   fill!(df.map_size, model.map_size)
   fill!(df.flower_width, model.flower_width)
   fill!(df.init_num_bphs, model.init_num_bphs)
   fill!(df.init_pr_eliminate, model.init_pr_eliminate)
   fill!(df.energy_transfer, model.energy_transfer)
   fill!(df.pct_rices, 0.0f0)
   fill!(df.num_nymphs, 0)
   fill!(df.num_eggs, 0)
   fill!(df.num_macros, 0)
   fill!(df.num_brachys, 0)
   fill!(df.num_females, 0)

   for t in 1:num_steps
      df[t, :pct_rices] = model.pct_rices
      df[t, :num_eggs] = model.num_eggs
      df[t, :num_nymphs] = model.num_nymphs
      df[t, :num_brachys] = model.num_brachys
      df[t, :num_macros] = model.num_macros
      df[t, :num_females] = model.num_females
      step!(model, 1)
   end
   return df
end

export init_model, agent_step!, model_step!, run!, MDATA, run_ricebph!

end
