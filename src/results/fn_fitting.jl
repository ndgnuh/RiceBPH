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

function try_fit(model, x, y, base_params, names)
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
    return merge(ret_p, ret_c)
end

"""
    qcd(x::Vector{<:Real})

Return quartile coefficient of dispersion for `x`.
Quantile is computed with `beta = alpha = 0`.
"""
function qcd(x)
    q1 = quantile(x, 0.25; beta = 0, alpha = 0)
    q3 = quantile(x, 0.75; beta = 0, alpha = 0)
    abs((q3 - q1) / (q3 + q1))
end

function compute_global_stats(params_df, names::Vector)
    gstats = map([mean, std, minimum, maximum, qcd]) do func
        mapreduce(merge, names) do name
            Dict(:stat => Symbol(func), name => func(params_df[!, name]))
        end
    end
    df = DataFrame(gstats)
    select!(df, vcat(:stat, names)) # Reordering
end

function compute_global_stats(df, factor)
    stat_names = names(df)
    filter!(!isequal("seed"), stat_names)
    mapreduce(merge, stat_names) do name
        values = filter(!ismissing, df[!, name])
        values = filter!(!isnan, values)
        values = Symbol(name) == factor ? unique(values) : values
        stat = map([mean, std, minimum, maximum, qcd]) do fn
            Float64(fn(values))
        end
        Dict(Symbol(name) => stat)
    end
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
        # Use data from which step
        steps = if stablesteps
            1:argmax(g.num_bphs)
        else
            Colon()
        end
        x = g[steps, :step] * 1.0f0
        y = g[steps, column] * 1.0f0

        # Try to fit the model
        base_params = init_params(model, x, y)
        result = try_fit(model, x, y, base_params, names)
        next!(pbar)
        return result
    end
end

"""
    factor_group_fit(f, result_df, column::Symbol; stablesteps=false)

Fit parameters of `f` and return the results dataframe for each value of factor.
Group the input data by factors, function `f` is fit on all the data for each
value of the input factor.
"""
function factor_group_fit(model, results, column;
                          stablesteps = false,
                          factor = get_factor_name(results),
                          names = get_param_names(model))
    groups = groupby(results, factor)

    pbar = Progress(length(groups))
    combine(groups) do g
        steps = if stablesteps
            1:g.step[argmax(g.num_bphs)]
        else
            Colon()
        end

        x = g[steps, :step] * 1.0f0
        y = g[steps, column] * 1.0f0

        # Fit parameters
        base_params = init_params(model, x, y)
        result = try_fit(model, x, y, base_params, names)
        next!(pbar)
        return result
    end
end
