using Printf
using Distributions

function randt(rng, T, d)
    trunc(T, rand(rng, d))
end

#
# Helpers
#
@doc raw"""
    normal_range(a, b; mul=1)

Return a [Normal](https://juliastats.org/Distributions.jl/stable/univariate/#Distributions.Normal) distribution with mean ``\mu'`` and standard deviation ``\sigma'`` determined by:
```math
\begin{align}
a & =\mu-\sigma,\\
b & =\mu+\sigma.
\end{align}
```
The found mean and standard deviation is scaled by `mul` variable to obtain the final mean and deviation.
```math
\begin{align}
\mu' &= \mu \cdot \mathrm{mul}, \\
\sigma' &= \sigma \cdot \mathrm{mul}.
\end{align}
```
"""
function normal_range(a, b; mul = 1)
    μ = (a + b) / 2.0f0
    σ = (b - a) / 2.0f0
    return Normal(μ * mul, σ * mul)
end

"""
    normal_hour_range(a, b)

Return `normal_range(a, b; mul=24)`. See [`normal_range`](@ref) for details.
"""
normal_hour_range(a, b) = normal_range(a, b; mul = 24.0f0)

"""
    normalize(v)

Return a probability vector ``v'`` with ``v`` as the Weight:
```math
v' = \\frac{v}{\\sum_{i} v_i}.
```
"""
function normalize(v)
    return v / sum(v)
end

"""
    show_dist(d)

Return LaTeX string for normal distribution.
"""
function show_dist(d::Normal)
    μ = d.μ
    σ = d.σ
    return @sprintf "``\\mathcal{N}(%.2f, %.2f)``" μ σ
end

"""
    show_dist(d)

Return LaTeX string for poisson distribution.
"""
function show_dist(d::Poisson)
    return @sprintf "``\\mathrm{Poi}(%.2f)``" d.λ
end
