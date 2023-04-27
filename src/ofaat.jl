module OFAAT


using Distributed
using ProgressMeter
using Distributed
using CSV
using DataFrames
using Printf: Format, format
using ..Model: init_model, agent_step!, model_step!, run!


const MODEL_DATA = [
  :num_rices,
  :num_eggs, :num_nymphs,
  :num_macros, :num_brachys
]


function generate_name(seed::Integer, factor::Symbol, value)
  fmt = Format("%s-%.4f+seed-%04d.csv")
  name = format(fmt, factor, value, seed)
  return joinpath(tempdir(), name)
end

function run_replicate!(num_steps, seed, factor, value, model_data, kw)
  # Generate a name
  output_csv = generate_name(seed, factor, value)

  # Run the simulation
  model = init_model(; factor => value, kw...)
  _, mdf = run!(
    model, agent_step!, model_step!, num_steps;
    mdata=model_data
  )

  # Write to temporary CSV
  num_rows = size(mdf, 1)
  mdf[!, factor] = fill(value, num_rows)
  mdf[!, :seed] = fill(seed, num_rows)
  CSV.write(output_csv, mdf)

  # Return the name
  return output_csv
end


function run_ofaat!(
  num_steps::Integer,
  num_replicates::Integer,
  factor::Symbol,
  values;
  model_data::Vector=MODEL_DATA,
  kw...
)
  @info kw
  list_files = String[]
  for value in values
    @info "Running $(factor) = $(value)"
    list_files_i = String[]
    list_files_i = let map_func(seed) = run_replicate!(
        num_steps, seed, factor, value, model_data, kw
      )
      @showprogress pmap(map_func, 1:num_replicates)
    end
    append!(list_files, list_files_i)
  end

  # Merge result CSVs
  @info "Merging results"
  result = mapreduce(vcat, list_files) do output_file
    mdf = CSV.read(output_file, DataFrame)
    rm(output_file)
    return mdf
  end
  return result
end


# End of module
end
