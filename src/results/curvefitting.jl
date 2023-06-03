using Statistics
using LinearAlgebra
using LsqFit
using DataFrames

function _legitify(x, fallback)
    if isnan(x) || isinf(x)
        return fallback
    else
        return x
    end
end

function step_function(t::T) where {T}
    @. t >= 0 ? one(T) : zero(T)
end

function logistic(t, A, T, K)
    @. A + (1 - A) / (1 + exp((t - T) * K))
end
logistic(t, params) = logistic(t, params...)

function damping_sine(t, μ, α, λ, ω, φ)
    # 2500 is for numerical stability
    @. μ + α * exp(-λ * t) * sin(ω * t / 2500 + φ)
end
damping_sine(t, params) = damping_sine(t, params...)

function step_logistics(t, params)
    A1, A2, T1, T2, K1, K2, τ = params
    mask = step_function(@. t - τ)
    (1 - mask) .* logistic(t, A1, T1, K1) .+ mask .* logistic(t, A2, T2, K2)
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

function init_params(::typeof(damping_sine), x, y)
    μ = mean(y)
    α = std(y)
    μ = _legitify(μ, y[end])
    α = _legitify(μ, y[maximum] - y[minimum])
    λ = 0.5f0
    ω = 1
    φ = 0.0f0
    return [μ, α, λ, ω, φ]
end

function init_params(::typeof(logistic), x, y)
    t0 = mean(x[y .≈ 0.5f0])
    t0 = _legitify(t0, one(eltype(t0)))
    return [0, t0, 0]
end

function fit_by_group(model, results, factor, column; stablesteps = false)
    names = get_param_names(model)
    groups = groupby(results, Cols(factor, :seed))

    combine(groups) do g
        steps = if stablesteps
            1:argmax(g[!, column])
        else
            Colon()
        end
        x = g[steps, :step]
        y = g[steps, column]

        base_params = init_params(model, x, y)
        fit = curve_fit(model, x, y, base_params)

        ret_p = NamedTuple(k => v for (k, v) in zip(names, fit.param))
        ret_c = (; converged = fit.converged)
        return merge(ret_p, ret_c)
    end
end

get_param_names(::typeof(logistic)) = [:A, :T, :K]
get_param_names(::typeof(damping_sine)) = [:μ, :α, :λ, :ω, :φ]

function compute_factor_stats(params_df, factor, names)
    combine(groupby(params_df, factor)) do g
        compute_global_stats(g, names)
    end
end
