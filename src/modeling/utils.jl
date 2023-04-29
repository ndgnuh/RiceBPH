function randt(rng, T, d)
    trunc(T, rand(rng, d))
end

#
# Helpers
#
"""
    normal_range(a, b; mul=1)

Return a Normal distribution with a = μ - σ and b = μ + σ.
"""
function normal_range(a, b; mul = 1)
    μ = (a + b) / 2.0f0
    σ = (b - a) / 2.0f0
    return Normal(μ * mul, σ * mul)
end

"""
    normal_hour_range(a, b)

Return `normal_range(a, b; mul=24)`.
"""
normal_hour_range(a, b) = normal_range(a, b; mul = 24.0f0)

"""
    normalize(v)

Return a probability vector with v as the Weight.
"""
function normalize(v)
    v / sum(v)
end
