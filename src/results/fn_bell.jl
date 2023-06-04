function bell_curve(t, μ, σ, k)
    # Again, 2550 are constants for numerical stability
    @. k * exp(-(t - μ / 2500.0f0)^2 / σ^2) / 5000.0f0
end
function bell_curve(t, params)
    bell_curve(t, params...)
end

function init_params(::typeof(bell_curve), x, y)
    μ = maximum(x) / 2.0f0
    σ = 1
    k = maximum(y)
    return [μ, σ, k]
end

function get_param_names(::typeof(bell_curve))
    return [:μ, :σ, :k]
end
