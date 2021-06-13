### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# ╔═╡ acc1f923-ff96-4edb-9c4e-13ed4a55f871
begin
	using Pkg
	Pkg.activate("..")
	using GradProject.PostProcess
end

# ╔═╡ f329fe9e-cb9b-11eb-1e8b-e7b224d1d323
using JLD2, PlutoUI, CairoMakie, DataFrames, CSV, Statistics

# ╔═╡ 8a9e6ee0-967b-4366-ba93-387a912c2e42
using Clustering

# ╔═╡ 48a326b4-cac9-43a8-b0e6-b2dfadcc8be3
using DataFramesMeta

# ╔═╡ 44833546-b966-430e-a4d1-2a51150f1e8b
using Latexify

# ╔═╡ f64c2ce4-2f5a-4db9-94b4-498620d8886c
files = joinpath.("../results", readdir("../results"))

# ╔═╡ 07b2fed7-dd09-4848-ad76-24aa305247ed
function ma(X, k)
	pad = zeros(eltype(X), k ÷ 2)
	[pad; [mean(X[i:(i+k)]) for i in 1:length(X) - k]; pad]
end

# ╔═╡ 85c54663-ba49-4b4c-bb3d-aff8f7f09636
function peak_population(X; smooth = 48 * 7 ÷ 2, threshold=0.0)
	# Smooth signal
	Y = X
	Y = ma(X, smooth)
	# Normlize
	MX = maximum(Y)
	mX = minimum(Y)
	Y = (Y .- mean(Y)) ./ std(Y)
	
	# Find the peaks	
	peaks = let r = Y .≥ threshold
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

# ╔═╡ d1c54595-d257-4115-91f2-d9802fb2053a
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

# ╔═╡ 0356fe38-14ef-4470-9506-bbdec875c222
function parsefile(path)
	meta = jldopen(f -> f["metadata"], path)
	name = last(split(meta.envmap, r"[\\/]"))
	(meta..., envmap=name, path=path)
end

# ╔═╡ 4cd2a9b0-c599-4b50-a96b-e9a46e32d7bf
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

# ╔═╡ e09b9532-1872-4ae7-8472-f48e668b9806
peakdf = let df = DataFrame(parsefile.(files))
	df
	df = transform(df, :path => ByRow(file2peaks) => :peaks) 
end

# ╔═╡ 4c735053-adb2-4b3e-b3a6-e518e54c0e30
statpeak = splitpeaks(peakdf)

# ╔═╡ 553e76b2-349a-4719-9dac-792803534c84
cleanpeak = let to_day = x -> @. round(x / 24, digits=1)
	cols = names(statpeak)
	cols = filter(x -> occursin("peak", x), names(statpeak))
	tfm = map(cols) do col
		col => to_day => col
	end
	transform(statpeak, tfm...)
end

# ╔═╡ 3cbc8ee8-d2e8-41c6-a088-e273119aad26
cleandf2 = let df = cleanpeak
	df = @where(df, (:pr_killed .== 0.15) .| (:pr_killed  .== 0))
	df = select(df,  [[3, 1, 4, 2]; 5:size(df, 2)])
	df = transform(df, :envmap => ByRow(function(x)
				if x == "no-flower.csv"
					[0, missing]
				else
					m = match(r"(\d+)-(\d+x\d+).csv", x)
					if isnothing(m)
						[0, x]
					else
						[parse(Int, m[1]), m[2]]
					end
				end
			end) => [:F, :envmap])
	df = sort(df, [:F, :envmap, :pr_killed, :init_position, :nb_bph_init], rev=true)
	df = let cols = string.([:F, :envmap, :pr_killed, :init_position, :nb_bph_init]) 
		dcols = setdiff(names(df), cols)
		select(df, [cols; dcols])
	end
	cols = names(df)
	cols = map(enumerate(cols)) do (i, name)
		if i == 1
			raw"$F$"
		elseif i == 2
			raw"$L$"
		elseif i == 3
			raw"$\Pr_{\text{kill}}$"
		elseif i == 4
			raw"$P_0$"
		elseif i == 5
			raw"$N$"
		else
			name = replace(raw"$" * name * raw"$", "std" => raw"\sigma")
			name = replace(name, r"sigma_peak_(\d+)" => s"sigma(t_\1)")
			name = replace(name, raw"$sigma" => raw"$\sigma")
			name = replace(name, r"peak_(\d+)" => s"mu(t_\1)")
			name = replace(name, "mu(t_" => raw"\mu(t_")
		end
	end
	df = rename(df, cols)
	n = size(df, 2)
	# df = select(df, Not([n, n-1]))
	df
end

# ╔═╡ 8c263acf-8585-462a-a6b3-617161c6c3eb
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


# ╔═╡ b1e1589a-f3fa-4756-af4a-308d268c006b
formaltable(cleandf2)

# ╔═╡ af6b92d3-1cd7-44c3-b417-2965406badaa
peakdfcsv = let df = CSV.read("all-peak-data.csv", DataFrame)
	transform(df, :peaks => ByRow(x -> eval(Meta.parse(x))) => :peaks)
end

# ╔═╡ 4ace47db-2992-4c0e-9076-9f37d4f52b6a
_statpeak = let df = splitpeaks(peakdfcsv)
	to_day = x -> @. round(x / 24, digits=1)
	cols = names(df)
	cols = filter(x -> occursin("peak", x), names(df))
	tfm = map(cols) do col
		col => to_day => col
	end
	transform(df, tfm...)
end

# ╔═╡ f7d70d28-e1f0-4369-8319-0c2661fd348e
finalpeak = let df = _statpeak
	df = @where(df, (:pr_killed .== 0.15) .| (:pr_killed  .== 0))
	df = select(df,  [[3, 1, 4, 2]; 5:size(df, 2)])
	df = transform(df, :envmap => ByRow(function(x)
				if x == "no-flower.csv"
					[0, missing]
				else
					m = match(r"(\d+)-(\d+x\d+).csv", x)
					if isnothing(m)
						[0, x]
					else
						[parse(Int, m[1]), m[2]]
					end
				end
			end) => [:F, :envmap])
	df = sort(df, [:F, :envmap, :pr_killed, :init_position, :nb_bph_init], rev=true)
	df = let cols = string.([:F, :envmap, :pr_killed, :init_position, :nb_bph_init]) 
		dcols = setdiff(names(df), cols)
		select(df, [cols; dcols])
	end
	cols = names(df)
	cols = map(enumerate(cols)) do (i, name)
		if i == 1
			raw"$F$"
		elseif i == 2
			raw"$L$"
		elseif i == 3
			raw"$\Pr_{\text{kill}}$"
		elseif i == 4
			raw"$P_0$"
		elseif i == 5
			raw"$N$"
		else
			name = replace(raw"$" * name * raw"$", "std" => raw"\sigma")
			name = replace(name, r"sigma_peak_(\d+)" => s"sigma(t_\1)")
			name = replace(name, raw"$sigma" => raw"$\sigma")
			name = replace(name, r"peak_(\d+)" => s"mu(t_\1)")
			name = replace(name, "mu(t_" => raw"\mu(t_")
		end
	end
	df = rename(df, cols)
	n = size(df, 2)
	# df = select(df, Not([n, n-1]))
	df
end

# ╔═╡ 7d9f469e-c857-4589-8339-da4c0e79d597
peakto_report = let n = size(finalpeak, 2)
	df = select(finalpeak, [1:5; 6+2*3:n])
	# df = select(finalpeak, 1:n-2*3)
	df = DataFrame(filter(eachrow(df)) do r
			!all(ismissing, r[end-5:end])
	end)
	
	formaltable(df)
end

# ╔═╡ 5e463e13-2215-42f5-8112-6987d202e65d
testdf = PostProcess.batch_test_rice("../results", 0.01; alpha=0.05, clean=true)

# ╔═╡ 9fd36c91-e299-4662-83ef-93bb8f290692
newnames=[
	:pr_killed => raw"$\Pr_{\text{kill}}$",
	:init_position => raw"$P_0$",
	:layout => raw"$L$",
	:nb_bph_init => raw"$N$",
]

# ╔═╡ 05e937cd-9395-4bb8-bbf7-de59b3f8e04e
function clean(df; ditch, group, key, val, newnames = nothing, sortcols=nothing)
	df = select(df, Not(ditch))
	function parseenvmap(m)
		ma = match(r"(\d+)-(\dx\d).csv", m)
		parse(Int, ma[1]), ma[2]
	end
	df = transform(df, :envmap => ByRow(parseenvmap) => [:flower, :layout])
	df = select(df, Not(:envmap))
	df = [unstack(d, key, val) for d in groupby(df, group)]
	df = vcat(df...)
	
	if !isnothing(sortcols)
		df = sort(df, sortcols)
		sortcols = String.(sortcols)
		othercols = setdiff(names(df), sortcols)
		df = select(df, [sortcols; othercols])
	end
	if !isnothing(newnames)
		df = rename(df, newnames)
	end
	return df
end


# ╔═╡ 05f9321d-0272-4720-9e0c-1b76358a1b1c
sortcols = [:pr_killed, :layout, :init_position, :nb_bph_init]

# ╔═╡ ad29fa9e-175f-4168-acac-a74b5e7f11a0
function clean_for_k(df)
	clean(df;
		ditch=[:accept, :n], 
		group=[:pr_killed, :layout],
		key=:flower,
		val=:k,
		newnames=newnames,
		sortcols = sortcols		
	)
end


# ╔═╡ b4b9588e-5a68-43e6-83f4-9c937f57a445
function clean_for_h0(df)
	clean(df;
		ditch=[:k, :n], 
		group=[:pr_killed, :layout],
		key=:flower,
		val=:accept,
		newnames=newnames,
		sortcols=sortcols,
	)
end

# ╔═╡ d8126628-ee50-4d73-afa1-6e6b3a355bc8
testdf2 = @where(testdf, (:envmap .!= "no-flower.csv") .& (:pr_killed .> 0));

# ╔═╡ e6a060d5-0ffc-4a71-bbe6-df8d7fb5b15a
formaltable(clean_for_k(testdf2))

# ╔═╡ Cell order:
# ╠═f329fe9e-cb9b-11eb-1e8b-e7b224d1d323
# ╠═f64c2ce4-2f5a-4db9-94b4-498620d8886c
# ╠═07b2fed7-dd09-4848-ad76-24aa305247ed
# ╠═85c54663-ba49-4b4c-bb3d-aff8f7f09636
# ╠═d1c54595-d257-4115-91f2-d9802fb2053a
# ╠═0356fe38-14ef-4470-9506-bbdec875c222
# ╠═4cd2a9b0-c599-4b50-a96b-e9a46e32d7bf
# ╠═8a9e6ee0-967b-4366-ba93-387a912c2e42
# ╠═e09b9532-1872-4ae7-8472-f48e668b9806
# ╠═4c735053-adb2-4b3e-b3a6-e518e54c0e30
# ╠═553e76b2-349a-4719-9dac-792803534c84
# ╠═48a326b4-cac9-43a8-b0e6-b2dfadcc8be3
# ╠═3cbc8ee8-d2e8-41c6-a088-e273119aad26
# ╠═44833546-b966-430e-a4d1-2a51150f1e8b
# ╠═b1e1589a-f3fa-4756-af4a-308d268c006b
# ╠═8c263acf-8585-462a-a6b3-617161c6c3eb
# ╠═af6b92d3-1cd7-44c3-b417-2965406badaa
# ╠═4ace47db-2992-4c0e-9076-9f37d4f52b6a
# ╟─f7d70d28-e1f0-4369-8319-0c2661fd348e
# ╠═7d9f469e-c857-4589-8339-da4c0e79d597
# ╠═acc1f923-ff96-4edb-9c4e-13ed4a55f871
# ╠═5e463e13-2215-42f5-8112-6987d202e65d
# ╠═9fd36c91-e299-4662-83ef-93bb8f290692
# ╠═05e937cd-9395-4bb8-bbf7-de59b3f8e04e
# ╠═05f9321d-0272-4720-9e0c-1b76358a1b1c
# ╠═ad29fa9e-175f-4168-acac-a74b5e7f11a0
# ╠═b4b9588e-5a68-43e6-83f4-9c937f57a445
# ╠═d8126628-ee50-4d73-afa1-6e6b3a355bc8
# ╠═e6a060d5-0ffc-4a71-bbe6-df8d7fb5b15a
