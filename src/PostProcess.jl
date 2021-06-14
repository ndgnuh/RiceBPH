module PostProcess

using DataFrames
using JLD2
using PlotlyJS
using HypothesisTests
using Clustering
using Statistics

function ma(X, k)
    pad = zeros(eltype(X), k ÷ 2)
    return [pad; [mean(X[i:(i + k)]) for i in 1:(length(X) - k)]; pad]
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
            a + offset
        end
    end
end

function peak_population(file::AbstractString; kwargs...)
    peaks = jldopen(file) do f
        map(1:1000) do seed
            df = f["$seed"]
            peak_population(df.count_bph; kwargs...)
        end
    end
    peaks = let lens = length.(peaks)
        s = std(lens)
        m = mean(lens)
        a, b = m - 3s, m + 3s
        filter(x -> a ≤ length(x) ≤ b, peaks)
    end
    npeaks = maximum(length.(peaks))
    peaks = reduce(vcat, peaks)

    cl = kmeans(transpose(peaks), npeaks)
    peaks = map(1:npeaks) do k
        peaks[k .== cl.assignments]
    end
    mpeaks = mean.(peaks)
    perm = sortperm(mpeaks)
    return peaks[perm]
end

function bname(fpath)
    return split(fpath, r"[\\/]")[end]
end

"""
    metadata(file::AbstractString)

Get metadata from file
"""
function metadata(file::AbstractString)
    return jldopen(f -> f["metadata"], file, "r")
end

function merge_result(file::AbstractString)
    io = jldopen(file, "r")
    df = DataFrame(; step=0:2880)
    foreach(keys(io)) do k
        if all(isdigit.(collect(k)))
            seed = parse(Int, k)
            df_seed = io[k]
            for name in names(df_seed)
                if name === "step"
                    continue
                end
                df[!, "$(name)_$(string(seed; pad=4))"] = df_seed[!, name]
            end
        end
    end
    columns = ["step"; sort(setdiff(names(df), ["step"]))]
    close(io)
    return select!(df, columns)
end

function PlotlyJS.plot(filepath::AbstractString, attr)
    f = jldopen(filepath, "r")
    traces = map(1:1000) do seed
        key = string(seed)
        df = f[key]
        scatter(; x=df.step, y=df[:, attr], name="Seed $key")
    end
    filebasename = splitpath(filepath)[end]
    title = replace(filebasename, "_" => "\n")
    layout = Layout(; title="$title", xaxis_title="Step", yaxis_title="$attr")
    close(f)
    return plot(traces, layout)
end

function plot_bph(filepath)
    return plot(filepath, :count_bph)
end
function plot_rice(filepath)
    return plot(filepath, :food)
end

function test_rice(filepath::AbstractString, p0)
    f = jldopen(filepath, "r")
    passed = map(1:1000) do seed
        key = string(seed)
        df = f[key]
        df.food[end] < df.food[begin] ÷ 2 - 100
    end
    close(f)
    return t = BinomialTest(count(passed), length(passed), p0)
end

function is_flower_effective(t; alpha=0.05)
    # H0: flower is not effective -> p = p0
    # Ha: flower is effective -> p < p0 -> tail = left
    # good -> reject H0 -> alpha > pvalue
    #a, b = confint(t; tail=:right, level=1-alpha)
    return alpha ≥ pvalue(t; tail=:left)
end

function test_rice(files::AbstractVector, p0; alpha=0.05)
    metadata = map(files) do file
        jldopen(f -> f["metadata"], file)
    end
    df = DataFrame(metadata)
    df.test = map(files) do file
        test_rice(file, p0)
    end
    df = transform(
        df,
        :envmap => ByRow(bname) => :envmap,
        :test => ByRow(t -> t.x) => :k,
        :test => ByRow(t -> t.n) => :n,
        :test => ByRow(t -> is_flower_effective(t; alpha=alpha)) => :accept,
    )
    return df
end

function batch_test_rice(dir::AbstractString, p0; alpha, clean=false)
    files = joinpath.(dir, readdir(dir))
    files = filter(files) do f
        isfile(f) && endswith(f, ".jld2")
    end
    df = test_rice(files, p0; alpha=alpha)
    if clean
        transform!(df, :test => ByRow(is_flower_effective) => :h0)
        select(df, Not("test"))
    else
        df
    end
end

function batch_peak_population(dir::AbstractString; kwargs...)
    files = joinpath.(dir, readdir(dir))
    map(files) do file
        file => peak_population(file; kwargs...)
    end
end

export JLD2,
    PlotlyJS,
    ProgressMeter,
    HypothesisTest,
    plot,
    savefig,
    test_rice,
    peak_population,
    batch_test_rice,
    batch_peak_population

# end module
end
