module OFAAT

using ProgressMeter
using Distributed
using CSV
using DataFrames
using Printf: Format, format
using ..Models: init_model, agent_step!, model_step!, run!, MDATA

function generate_name(seed::Integer, factor::Symbol, value)
    fmt = Format("%s-%.4f+seed-%04d.csv")
    name = format(fmt, factor, value, seed)
    return joinpath(tempdir(), name)
end

function run_replicate!(num_steps, seed, factor, value, kw)
    # Generate a name
    output_csv = generate_name(seed, factor, value)

    # Run the simulation
    model = init_model(; factor => value, kw...)
    _, mdf = run!(model, agent_step!, model_step!, num_steps;
                  mdata = MDATA)

    # Write to temporary CSV
    num_rows = size(mdf, 1)
    mdf[!, factor] = fill(value, num_rows)
    mdf[!, :seed] = fill(seed, num_rows)

    # Return the name
    GC.gc()
    return mdf
end

function run_ofaat!(num_steps::Integer,
                    num_replicates::Integer,
                    factor::Symbol,
                    values;
                    kw...)
    @info kw
    list_files = String[]
    result = mapreduce(vcat, values) do value
        @info "Running $(factor) = $(value)"
        map_func(seed) = run_replicate!(num_steps, seed, factor, value, kw)
        reduce(vcat, @showprogress pmap(map_func, 1:num_replicates))
    end

    # Merge result CSVs
    #= @info "Merging results" =#
    #= result = mapreduce(vcat, list_files) do output_file =#
    #=     mdf = CSV.read(output_file, DataFrame) =#
    #=     rm(output_file) =#
    #=     return mdf =#
    #= end =#
    return result
end

# End of module
end
