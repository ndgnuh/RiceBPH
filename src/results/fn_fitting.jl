using Statistics
using LinearAlgebra
using LsqFit
using DataFrames
using ProgressMeter

function _legitify(x, fallback)
    if isnan(x) || isinf(x)
        return fallback
    else
        return x
    end
end

function compute_global_stats(params_df, names)
    gstats = map([mean, std, minimum, maximum]) do func
        mapreduce(merge, names) do name
            Dict(:stat => Symbol(func), name => func(params_df[!, name]))
        end
    end
    df = DataFrame(gstats)
    select!(df, vcat(:stat, names)) # Reordering
end

function compute_factor_stats(params_df, factor, names)
    combine(groupby(params_df, factor)) do g
        compute_global_stats(g, names)
    end
end

function group_fit(model, results, column;
                   stablesteps = false,
                   factor = get_factor_name(results),
                   names = get_param_names(model))
    groups = groupby(results, Cols(factor, :seed))

    pbar = Progress(length(groups))

    combine(groups) do g
        steps = Colon()
        x = g[steps, :step]
        y = g[steps, column]

        # Try to fit the model
        base_params = init_params(model, x, y)
        fit = try
            curve_fit(model, x, y, base_params)
        catch e
            if e isa LinearAlgebra.SingularException
                (; param = base_params, converged = false)
            else
                rethrow(e)
            end
        end

        # Collect result 
        ret_p = NamedTuple(k => v for (k, v) in zip(names, fit.param))
        ret_c = (; converged = fit.converged)

        next!(pbar)
        return merge(ret_p, ret_c)
    end
end

"""
    factor_group_fit(f, result_df, column::Symbol; stablesteps=false)

Fit parameters of `f` and return the results dataframe for each value of factor.
Group the input data by factors, function `f` is fit on all the data for each
value of the input factor.
"""
function factor_group_fit(model, results, column; stablesteps = false)
    factor = get_factor_name(results)
    names = get_param_names(model)
    fgroups = groupby(results, factor)

    combine(fgroups) do fg
        steps = if stablesteps
            _steps = map(groupsby(fg, :seed)) do sg
                argmax(sg[!, :num_bphs])
            end
            max_step = trunc(Int, mean(_steps))
            1:max_step
        else
            Colon()
        end

        x = results[steps, :step]
        y = results[steps, column]
    end
end
