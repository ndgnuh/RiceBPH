module OFAAT

using Configurations
using ProgressMeter
using Distributed
using DataFrames
using Printf: Format, format
using ..Models: init_model, agent_step!, model_step!, run!, MDATA

@option struct FactorConfig
    name::String
    values::String
end

@option struct OFATConfig
    factor::FactorConfig
    base_params::Dict
end

"""
    run_replicate!(num_steps, seed, factor, value, kw)

Run a replication for `num_steps` steps.
The other parameters are used to initialize the model.
Returns model dataframe. The final dataframe contains extra columns to
represent seed and factor.
"""
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

"""
    run_ofaat!(num_steps, num_reps, factor, values; kw...)

Run one-factor-at-a-time replication experiment.
Return the combined dataframe created by concatnating the result dataframes from all the replication.
This function is the same as `paramscan` from `Agents.jl`, but `paramscan` does not do garbage collection, this one does to prevent out of memory error.
"""
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
