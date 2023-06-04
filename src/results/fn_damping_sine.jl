function damping_sine(t, μ, λ, ω, φ)
    # Divide by 1000 for numerical stability
    tn = @. t / 1000.0f0
    @. μ + exp(-λ * tn) * sin(ω * tn + φ)
end
damping_sine(t, params) = damping_sine(t, params...)

function init_params(::typeof(damping_sine), x, y)
    μ = mean(y)
    μ = _legitify(μ, y[end])
    λ = 1.0f0
    ω = 1
    φ = 0.0f0
    return [μ, λ, ω, φ]
end

get_param_names(::typeof(damping_sine)) = [:μ, :λ, :ω, :φ]
