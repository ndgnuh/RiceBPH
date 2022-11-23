using DataFrames
using HypothesisTests
using Clustering
using Statistics
using JLD2

function moving_average(X, k)
    pad = zeros(eltype(X), k ÷ 2)
    return [pad; [mean(X[i:(i + k)]) for i in 1:(length(X) - k)]; pad]
end

function peak_population(X::AbstractVector; smooth=48 * 7 ÷ 2, threshold=0.0)
    # Smooth signal
    Y = X
    Y = moving_average(X, smooth)
    # Normlize
    MX = maximum(Y)
    mX = minimum(Y)
    Y = (Y .- mean(Y)) ./ std(Y)
    # Find the peaks
    return let r = Y .≥ threshold
        ranges = findall(isone, abs.(diff(r)))
        if isodd(length(ranges))
            push!(range, length(X))
        end
        map(Iterators.partition(ranges, 2)) do (a, b)
            _, offset = findmax(@view X[a:b])
            return a + offset
        end
    end
end

function is_flower_effective(t; alpha=0.05)
    # H0: flower is not effective -> p = p0
    # Ha: flower is effective -> p < p0 -> tail = left
    # good -> reject H0 -> alpha > pvalue
    # a, b = confint(t; tail=:right, level=1-alpha)
    return alpha ≥ pvalue(t; tail=:left)
end
