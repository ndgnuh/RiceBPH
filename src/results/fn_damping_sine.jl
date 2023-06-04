function damping_sine(t, μ, α, λ, ω, φ)
    # 2500 is for numerical stability
    @. μ + α * exp(-λ^2 * t) * sin(ω * t + φ)
end
damping_sine(t, params) = damping_sine(t, params...)

function init_params(::typeof(damping_sine), x, y)
    μ = mean(y)
    α = std(y)
    μ = _legitify(μ, y[end])
    α = _legitify(μ, maximum(y) - minimum(y))
    λ = 0.5f0
    ω = 1
    φ = 0.0f0
    return [μ, α, λ, ω, φ]
end

get_param_names(::typeof(damping_sine)) = [:μ, :α, :λ, :ω, :φ]
