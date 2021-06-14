module PostProcess

using DataFrames
using JLD2
using PlotlyJS
using HypothesisTests
using Clustering

function ma(X, k)
    pad = zeros(eltype(X), k ÷ 2)
    return [pad; [mean(X[i:(i + k)]) for i in 1:(length(X) - k)]; pad]
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

function test_rice(filepath, p0)
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
        select(df, Not("test"))
    else
        df
    end
end

export JLD2, PlotlyJS, ProgressMeter, HypothesisTest, plot, savefig, test_rice

# end module
end
	smooth = 4
	# a2 = Axis(f[1,2])
	n = length(X)
	lines!(a1, X)
	
	lines!(a1, ma(X, smooth))
	# lines!(a1, fill(mean(df.count_bph), n))
	# lines!(a1, fill(quantile(df.count_bph, 0.25), n))
	# lines!(a1, fill(quantile(df.count_bph, 0.75), n))
	lines!(a1, fill(thres * std(X) + mean(X), n))
	peaks = peak_population(X, threshold=thres, smooth=smooth)
	scatter!(a1, peaks, X[peaks])
	lines!(a1, peaks, X[peaks])
	f
end

# ╔═╡ f8950add-031c-4af6-af56-be09d60f3f8f
let f = Figure()
	ax = Axis(f[1, 1])
	jldopen(file) do f
		map(1:1000) do sd
			df = f["$sd"]
			lines!(ax, df.step, df.count_bph)
		end
	end
	f
end

# ╔═╡ 6e98acef-274a-4e7d-8d69-96dbc116c333
let f = Figure()
	ax = Axis(f[1, 1])
	jldopen(file) do f
		map(1:1000) do sd
			df = f["$sd"]
			lines!(ax, df.step/24, df.count_bph)
		end
	end
	f
end

# ╔═╡ 9ea40c9e-d563-454e-987a-a17574620bfa
import PlotlyJS

# ╔═╡ 9c81ba94-5993-47ec-a57c-11ab6bb1c89c
dinhray = let f = jldopen(file)
	traces = map(1:1000) do s
		df = f["$s"]
		PlotlyJS.scatter(; x = df.step/24, y = df.count_bph, legend=false, name="Seed $s")
	end
	close(f)
	p = PlotlyJS.plot(traces, PlotlyJS.Layout(showlegend=false))
	PlotlyJS.savefig(p, "/tmp/dinh-ray.png")
end

# ╔═╡ b042ad4f-48e2-480b-93ba-ae6b4c94b6d2
LocalResource(dinhray)

# ╔═╡ 2820e1eb-80bb-4a1e-9d80-2bdd00f8bea7
DownloadButton(read(dinhray), splitpath(dinhray)[end])

# ╔═╡ de405835-0d61-4b68-bf94-ab7d796a69c6
md"# Batch peak data"

# ╔═╡ 68e35a9d-ab6e-420f-9c96-866b7fab75a8
function file2peaks(file)
	peaks = jldopen(file) do f
		map(1:1000) do seed
			df = f["$seed"]
			peak_population(df.count_bph)
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
	peaks[perm]
end

# ╔═╡ 0a70ede0-63b8-44cf-953e-cf081d7e5759
file2peaks(file)

# ╔═╡ 3005e698-d920-4767-bbcb-420c2739f591
md"# Peak across data files"

# ╔═╡ eb459b23-2f8b-4d9a-a349-5ddee45cc9bf
function parsefile(path)
	meta = jldopen(f -> f["metadata"], path)
	name = last(split(meta.envmap, r"[\\/]"))
	(meta..., envmap=name, path=path)
end

# ╔═╡ d8b94bd2-e0e7-4da3-9582-726f28269232
peakdf = let df = DataFrame(parsefile.(files))
	df
	df = transform(df, :path => ByRow(file2peaks) => :peaks) 
end

# ╔═╡ 6cd527cd-0eb7-43c2-98a2-d2164e7d8187
function splitpeaks(df)
	function getstat(stat, x, n)
		stat(get(x, n, [missing]))
	end
	npeaks = maximum(length.(df.peaks))
	transformation = map(1:npeaks) do n
		[:peaks => ByRow(x -> getstat(mean, x, n)) => Symbol("peak_$n"),
		:peaks => ByRow(x -> getstat(std, x, n)) => Symbol("std_peak_$n")]
	end
	df = transform(df, transformation...)
	df = select(df, Not([:peaks, :path]))
end

# ╔═╡ 3e1f5482-76e3-4ce8-a211-d50c482e0394
statpeak = splitpeaks(peakdf)

# ╔═╡ 72b5b845-c7e2-4028-844b-deea0aec22ca
cleanpeak = let to_day = x -> @. round(x / 24, digits=1)
	cols = names(statpeak)
	cols = filter(x -> occursin("peak", x), names(statpeak))
	tfm = map(cols) do col
		col => to_day => col
	end
	transform(statpeak, tfm...)
end

# ╔═╡ 2b188539-5a31-4b89-84e9-382b95218a80
cleandf2 = let df = cleanpeak
	df = @where(df, (:pr_killed .== 0.15) .| (:pr_killed  .== 0))
	df = select(df,  [[3, 1, 4, 2]; 5:size(df, 2)])
	df = sort(df, [:pr_killed, :envmap, :init_position, :nb_bph_init], rev=true)
	df = transform(df, :envmap => ByRow(x -> match(r"(\dx\d)", x)[1]) => :envmap)
	cols = names(df)
	cols = map(enumerate(cols)) do (i, name)
		if i == 2
			raw"$L$"
		elseif i == 1
			raw"$\Pr_{\text{kill}}$"
		elseif i == 3
			raw"$P_0$"
		elseif i == 4
			raw"$N$"
		else
			name = replace(raw"$" * name * raw"$", "std" => raw"\sigma")
			name = replace(name, r"sigma_peak_(\d+)" => s"sigma(t_\1)")
			name = replace(name, raw"$sigma" => raw"$\sigma")
			name = replace(name, r"peak_" => raw"t_")
		end
	end
	df = rename(df, cols)
	n = size(df, 2)
	df = select(df, Not([n, n-1]))
	df
end

# ╔═╡ 9dad2144-45c7-46f2-959f-c42093aeb63f
md"# Latex"

# ╔═╡ 12c6567b-4029-463e-8b80-a8c0cb0a64d5
function formaltable(df)
	s = latextabular(df; latex=false)
	lines = split(s, "\n")
	tbegin = replace(lines[1], "" => "")
	# header
	thead = strip(replace(lines[2], "\\\\" => ""))
	# thead = join("\\textbf{" .* split(thead, r" *& *") .* "}", " & ")
	tbody = join(lines[3:end-2], "\n\\midrule\n")
	s = """
	$(tbegin)
	\\toprule
	$(thead) \\\\
	\\midrule
	\\midrule
	$(tbody)
	\\bottomrule
	\\end{tabular}
	"""
	s = replace(s, r"([^a-zA-Z_.])([0-9]+\.?[0-9]*)([^a-zA-Z_.])" => s"\1$\2$\3")
	# s = replace(s, r"([0-9]+\.[0-9]+)" => s"$\1$")
	s = replace(s, "1x2" => raw"\OneByTwo")
	s = replace(s, "3x3" => raw"\ThreeByThree")
	s = replace(s, "false" => raw"\Reject")
	s = replace(s, "true" => raw"\Accept")
	s = replace(s, "corner" => raw"\Corner")
	s = replace(s, "border" => raw"\Border")
	# s = replace(s, r"_" => raw"\_")
	s = replace(s, "#" => raw"\#")
	s = replace(s, "missing" => "--")
	clipboard(s)
	return s
end


# ╔═╡ 5cf687c3-7d2f-4751-af5a-9c38ebb2d4f1
s = formaltable(cleandf2)

# ╔═╡ b619d9cb-64d2-4e88-9421-7a202d71f691
with_terminal(() -> println(s))

# ╔═╡ 6847a684-f74c-49df-baf3-c71ba4e102f4
write("population-peak.tex", s)

# ╔═╡ Cell order:
# ╠═ed7b7fa2-ca12-11eb-3142-830f24a474d2
# ╟─20e4a147-4f6f-4c21-97f4-a62cc6d24745
# ╠═9023aa1e-509a-4ca9-b35b-2d2875dda584
# ╠═087175fd-bc09-4623-91a5-b779c0fc62c8
# ╠═28d52568-c5de-4d0c-b2fc-a1e3a3690042
# ╠═22f38eaa-8e10-4dcd-a469-635cbb390480
# ╠═a3ab9801-22f8-4ee1-8be6-c33acf9007bb
# ╠═86e45cf0-0290-4350-bfdb-056073630021
# ╠═e18bc7ed-15c3-4e1d-a90b-75fc2367ae1b
# ╠═fbfd993c-3897-4c5c-b504-d8ace62762de
# ╟─c9e69c07-2b3b-40c5-9aaa-88407040e882
# ╠═d9bcb11b-61c0-48d0-a90a-72e0e766c22e
# ╠═5639f9fe-660c-430f-a7d2-3d1aad4d6152
# ╠═62586022-2d8a-43ef-98f0-a039d446cd25
# ╠═6aa63ead-af1e-4e1d-b3e7-60d3a0f700d4
# ╠═f8950add-031c-4af6-af56-be09d60f3f8f
# ╠═6e98acef-274a-4e7d-8d69-96dbc116c333
# ╠═9ea40c9e-d563-454e-987a-a17574620bfa
# ╠═9c81ba94-5993-47ec-a57c-11ab6bb1c89c
# ╠═b042ad4f-48e2-480b-93ba-ae6b4c94b6d2
# ╠═2820e1eb-80bb-4a1e-9d80-2bdd00f8bea7
# ╟─de405835-0d61-4b68-bf94-ab7d796a69c6
# ╠═b3ed17c4-213a-4547-b4be-2fd43612b563
# ╠═68e35a9d-ab6e-420f-9c96-866b7fab75a8
# ╠═0a70ede0-63b8-44cf-953e-cf081d7e5759
# ╟─3005e698-d920-4767-bbcb-420c2739f591
# ╠═eb459b23-2f8b-4d9a-a349-5ddee45cc9bf
# ╠═d8b94bd2-e0e7-4da3-9582-726f28269232
# ╠═6cd527cd-0eb7-43c2-98a2-d2164e7d8187
# ╠═3e1f5482-76e3-4ce8-a211-d50c482e0394
# ╠═7280ad9b-5a95-44c0-9a48-2b90195c176f
# ╠═72b5b845-c7e2-4028-844b-deea0aec22ca
# ╠═ee13068b-f94a-4c4d-9749-faa27e4c1d4e
# ╠═2b188539-5a31-4b89-84e9-382b95218a80
# ╠═9dad2144-45c7-46f2-959f-c42093aeb63f
# ╠═5b8f13a4-fbc8-470e-99d6-33cbbfdb9030
# ╠═12c6567b-4029-463e-8b80-a8c0cb0a64d5
# ╠═5cf687c3-7d2f-4751-af5a-9c38ebb2d4f1
# ╠═b619d9cb-64d2-4e88-9421-7a202d71f691
# ╠═6847a684-f74c-49df-baf3-c71ba4e102f4
