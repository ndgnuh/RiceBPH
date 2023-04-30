module OFAAT

using ProgressMeter
using Distributed
using DataFrames
using Printf: Format, format
using ..Models: init_model, agent_step!, model_step!, run!, MDATA

function generate_name(seed::Integer, factor::Symbol, value; suffix = ".jdf")
    fmt = Format("%s-%.4f+seed-%04d.%s")
    name = format(fmt, factor, value, seed, suffix)
    return joinpath(tempdir(), name)
end

function run_replicate!(num_steps, seed, factor, value, kw)
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
    result = mapreduce(vcat, values) do value
        @info "Running $(factor) = $(value)"
        map_func(seed) = run_replicate!(num_steps, seed, factor, value, kw)
        reduce(vcat, @showprogress pmap(map_func, 1:num_replicates))
    end

    return result
end

# End of module
end
