using DataFrames
using HypothesisTests
using Clustering
using Statistics
using JLD2

function ma(X, k)
    pad = zeros(eltype(X), k ÷ 2)
    return [pad; [mean(X[i:(i+k)]) for i in 1:(length(X)-k)]; pad]
end

function peak_population(X::AbstractVector; smooth=48 * 7 ÷ 2, threshold=0.0)
    # Smooth signal
    Y = X
    Y = ma(X, smooth)
    # Normlize
    MX = maximum(Y)
    mX = minimum(Y)
    Y = (Y .- mean(Y)) ./ std(Y)
    # Find the peaks
    return peaks = let r = Y .≥ threshold
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

function test_effectiveness(foods::AbstractMatrix, p0; alpha=0.05)
    # foods: [time, experiment]
    # p0: chances that the crop will suffer from the BPH (risk probablity)
    # alpha: pvalue threshold

    # 100 allows a bit of deviation, incase the result is really really close
    goods = @views foods[end, :] .≥ (foods[begin, :] * 0.5 .- 100)
    _, total = size(foods)
    num_goods = count(goods)

    # Perform a left tail testing
    # H0: flower is effective: good / total ≥ p0
    # H1: flower is not effective: good / total < p0
    # Effective means accept H0, which means pvalue < alpha
    # H1 is p < p0, which means the tail is on the left
    test = BinomialTest(num_goods, total, p0)

    # pvalue function only calculates then tail's value
    pv = pvalue(test; tail=:left)
    effective = alpha < pv
    return (; pvalue=pv, total=total, num_goods=num_goods, effective=effective, goods=goods)
end

"""
    test_effectiveness(foods; alpha=0.05)

Returns (; test, pass, pvalue) where `test` is a OneSampleTTest,
`pass` is a Bool indicate whether we accept that the flow is effective or not.

The criteria is whether the amount of protected rice is at least `0.5`.
"""
function test_effectiveness(foods::AbstractMatrix; alpha=0.05)
    # foods: [time, experiment]
    # p0: chances that the crop will suffer from the BPH (risk probablity)
    # alpha: pvalue threshold

    # Food retain ratio
    food_ratios = foods[end, :] ./ foods[begin, :]

    # Perform T-Test
    # r: food retain ratio
    # H0: r = 0.5
    # H1: r > 0.5
    # Good == reject H0 == pvalue < alpha
    test = OneSampleTTest(food_ratios, 0.5)
    pvalue = HypothesisTests.pvalue(test, tail=:right)
    pass = pvalue < alpha

    # The result shown in the test repr is for BOTH size test
    # Don't trust those
    return (; test, pass, pvalue)
end
