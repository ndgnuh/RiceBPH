### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 5934e838-c887-11eb-3d34-5364828175f3
using JLD2, FFTW

# ╔═╡ 6490f3c9-828c-4a61-a21c-201ca2134772
using StatsBase

# ╔═╡ c9739713-12b6-43a7-afe2-6e4fea25b732
using DataFrames

# ╔═╡ 0ff69784-d617-476d-8793-7d82d8f1ef38
using Statistics

# ╔═╡ eb8fbe5e-edf9-452b-a83c-37b8d5258344
using CairoMakie

# ╔═╡ 5445a823-f610-47e0-81da-ee8a302271e1
using PlutoUI

# ╔═╡ 5dfb64de-c28c-4aa7-abca-80933117ce09
using Distributions

# ╔═╡ 23956119-4eca-490d-8f4e-bb001ecbdd7d
using Latexify

# ╔═╡ fd498b55-6d68-4418-8b50-de5cef64931a
using Clustering

# ╔═╡ b1b25bed-79ac-442a-8c10-985d8d40fdea
using CSV, DataFramesMeta

# ╔═╡ 46c9dbc9-6a9e-4393-a251-4b2bd1d7e638
using DelimitedFiles

# ╔═╡ 7338aa8b-63c8-440f-9e6b-172965b27c23
using HypothesisTests

# ╔═╡ b784697f-0644-40ef-97b7-e6fe4af4188e
resultdir = joinpath("..", "results")

# ╔═╡ 66571363-4357-4de9-b932-2731aa3a6b42
jlds = joinpath.(resultdir, filter(endswith("jld2"), readdir(resultdir)))

# ╔═╡ 909914e4-a7c1-4479-801d-9f92ccefafc4
function getlastrice(f)
	rices = jldopen(f) do io
		map(1:1000) do i
			df = io[string(i)]
			df.food[end] ≥ df.food[1] ÷ 2
		end
	end
	# convert.(Int32, rices)
end

# ╔═╡ 20b53174-e6ab-4035-a1aa-a1ad6a8b100b
readdir(resultdir)

# ╔═╡ a0d379a9-75be-4c18-87a3-7410d2bc912c
lastrices = getlastrice.(jlds)

# ╔═╡ ff5d4c71-b9dd-4028-8c92-3951a4ebcf3c
lastrices_ = filter(!isempty, convert.(Vector{Int32}, lastrices))

# ╔═╡ 011014c1-ac43-44a8-a358-c9d86ddeb6bf
stds = map(r -> std(r, corrected=false), lastrices_) 

# ╔═╡ 26862094-b78f-4984-89ef-aa25177c0492
means = map(mean, lastrices_)

# ╔═╡ c09ebe2c-e31a-49fd-9b36-2b653f682db5
function cvs(X)
	map(100:1000) do n
		std(X[1:n]) / mean(X[1:n])
	end
end

# ╔═╡ da80c530-f5be-4a52-937b-abbf366fff67
function dcvs(X)
	C = cvs(X)
	[abs(C[m] - C[n]) for m in 1:length(C), n in 1:length(C) if n > m]
end

# ╔═╡ 6d8c724a-cf10-4938-982c-7bff67480260
findmax(dcvs(lastrices[1]))

# ╔═╡ 5f56093d-3c6f-46a0-85ce-e0f5a6fc792f
function sliding(z, w)
	((@view z[i:i+w-1]) for i in 1:length(z)-w+1)
end

# ╔═╡ 7c96d734-9876-4215-810a-854afd73d90c
map(sum, sliding(1:10, 3))

# ╔═╡ 9477c96b-8a6b-49c0-8a22-ed91cebf3e30
jlds[1]

# ╔═╡ 8f252bb5-ae7e-4de3-a956-94ebfc056e1e
jldopen(jlds[1]) do f
	f["500"][900:905, :]
end 

# ╔═╡ 38fb200c-b683-4b02-9341-ecf6d0a3010f
@bind i PlutoUI.Slider(1:length(lastrices))

# ╔═╡ d967bfe9-da66-47be-9ecc-469ce324d633
wns = let X = lastrices[i]
	cs = map(sliding(X, 10)) do w
		std(w) / mean(X)
	end
	# map(2:length(cs)) do n
	# 	cov(cs[1:n])
	# end
end

# ╔═╡ daef4589-5ccf-4639-9f0d-4ecc15a1cb90
lines((wns / maximum(wns)))

# ╔═╡ b23c33cf-dffc-4bbd-b088-d51d67ec37df
function nmin_coeff(X, g; alpha=0.05, beta=0.95)
	V = length(X) - 1
	t = TDist(V)
	s = std(X)
	2 * s^2 / g * (quantile(t, 1 - alpha/2) + quantile(t, 1-beta/2))^2
end

# ╔═╡ 301520f9-1658-4e8a-b39b-7854ee6795d4
map(n -> nmin_coeff(lastrices[1][1:n], 5000), 2:1000)

# ╔═╡ 16375ff7-e018-4948-95c2-5c152afb3d0a
kmeans(lastrices[2] |> transpose, 2)

# ╔═╡ 02eae0af-570f-4a1d-9035-ba9be3efd7ef
const testresultdir = joinpath("..", "kiem-dinh")

# ╔═╡ 4068822f-5bd2-4b13-8919-18d5202ba54c
PlutoUI.TableOfContents()

# ╔═╡ 1b672c30-d567-4d1f-97e4-e462a314e434
md"# Sinh bảng"

# ╔═╡ 740dc4b4-4240-48fa-a164-4097353c48e2
testcsvs = joinpath.(testresultdir, readdir(testresultdir))

# ╔═╡ ee016a15-a598-451f-94c9-2b19f9c82673
@bind testcsv PlutoUI.Select(testcsvs)

# ╔═╡ 2c11fd74-711e-4781-b127-7fa01cfd5ed4
df = CSV.read(testcsv, DataFrame)

# ╔═╡ eea51e97-9f4e-41b5-b8f4-764e43bcb04f
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
	s = replace(s, r"([^a-zA-Z_.])([0-9]\.?[0-9]*)([^a-zA-Z_.])" => s"\1$\2$\3")
	# s = replace(s, r"([0-9]+\.[0-9]+)" => s"$\1$")
	s = replace(s, "1x2" => raw"\OneByTwo")
	s = replace(s, "3x3" => raw"\ThreeByThree")
	s = replace(s, "false" => raw"\Reject")
	s = replace(s, "true" => raw"\Accept")
	s = replace(s, "corner" => raw"\Corner")
	s = replace(s, "border" => raw"\Border")
	clipboard(s)
	return s
end

# ╔═╡ 41b5e3d7-5f39-4b55-b6be-3520c76c0924
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

# ╔═╡ ead4bf05-6319-49aa-bcf9-6a5bb50469ea
sortcols = [:pr_killed, :layout, :init_position, :nb_bph_init]

# ╔═╡ ec65b6c9-6851-470a-a8cf-1db53e4f143b
newnames=[
	:pr_killed => raw"$\Pr_{\text{kill}}$",
	:init_position => raw"$P_0$",
	:layout => raw"$L$",
	:nb_bph_init => raw"$N$",
]

# ╔═╡ fa49c376-e47c-4089-9d40-f1237c74f749
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

# ╔═╡ 3df31e23-605d-4833-ae3b-53f1770a487b
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

# ╔═╡ c0780832-f855-447a-a03b-6327e08261c8
names(df)

# ╔═╡ 9f89b857-9dc2-45b2-a6e4-a9de4ec24370
nicedf = let df = df#@where(df, :pr_killed .== 0.12)
	s = clean_for_k(df) |> formaltable
end

# ╔═╡ 3fa30047-885d-4710-a291-c969ead989c9
with_terminal() do
	print(nicedf)
end

# ╔═╡ 8e0ba929-10fd-4586-96e1-28f59490aa69
dfs = let csvs = map(testcsvs) do f
		last(splitpath(f))
		m = match(r"test-p0\+([0-9.]+)-alpha\+([0-9.]+).csv", f)
		(
			p0 = parse(Float32, m[1]),
			alpha =parse(Float32, m[2]),
			path = f
		)
	end
	DataFrame(csvs)
end

# ╔═╡ 99b16a23-3eb1-46d4-a4e5-21eab89f3f52
let texpath = joinpath(@__DIR__, "..", "tex")
	mkpath(texpath)
	map(eachrow(dfs)) do row
		df = CSV.read(row.path, DataFrame)
		map(unique(df.pr_killed)) do pk
			df_ = @where(df, :pr_killed .== pk)
			df_ = clean_for_h0(df_)
			s = formaltable(df_)
			write(joinpath(texpath, "p+$pk-p0+$(row.p0)-alpha-$(row.alpha).tex"), s)
		end
	end
	df = CSV.read(dfs[1, :path], DataFrame)
	map(unique(df.pr_killed)) do pk
		df_ = @where(df, :pr_killed .== pk)
		df_ = clean_for_k(df_)
		s = formaltable(df_)
		write(joinpath(texpath, "p-$pk.tex"), s)
	end
end

# ╔═╡ 3b71c9e7-bd76-4a3a-ba13-e0be6072f417
let n = 1000
	d = Binomial(n, 0.001)
	x = 0:n
	y = pdf.(d, x)
	lines(x, y)
end

# ╔═╡ b9d9c8d9-7ad2-4acb-b10f-b69ddd8db2d6
cdf(Binomial(1000, 0.01), 9)

# ╔═╡ aad68c8f-3575-4d9a-8335-4f1e5339b574
t1 = BinomialTest(13, 1000, 0.001)

# ╔═╡ b8e982f6-a7ea-4031-b971-ce9bf2b0fb88
@bind p0 PlutoUI.Select([0.05, 0.01, 0.005, 0.001, 0] .|> string)

# ╔═╡ 24e13415-cee9-4408-be4f-c00d3f17d01e
# H0, hoa ok p <= p0
# Ha, hoa ko ok, p >= p0
# k: so lan hoa ok
# n: tong so lan (1000)

# ╔═╡ 08f01fc4-f0c0-4a5d-a733-eab8296a1618


# ╔═╡ 8a18a998-b6b6-4d30-8132-8a3dfd5260f1
@bind n PlutoUI.Slider(0:1000)

# ╔═╡ 6f1630ff-16c9-4721-9707-97fb60479914
t2 = BinomialTest(n, 1000, parse(Float64, p0))

# ╔═╡ afd473a4-0aa6-4bed-9f4a-d36ad86d1fa5
function is_flower_effective(t, alpha)
	T = t.x / t.n
	a, b = confint(t2; level=1-alpha, tail=:both)
	(T, a, b)
end

# ╔═╡ 78d7cd1c-c05c-497e-a31d-c79efc2e7c2e
@bind α PlutoUI.Select(string.([0.1, 0.05, 0.01, 0.005]))

# ╔═╡ 9446695b-59bf-4d36-bb1b-b66456eb5ac7
pvalue(t2; tail=:left)

# ╔═╡ a4855f8d-9182-4870-ab98-746b89df2017
let alphas = [0.1, 0.05, 0.01, 0.005]
	cons = [confint(t2; level=1-alpha, tail=:left) for alpha in alphas]
	as = getindex.(cons, 1)
	bs = getindex.(cons, 2)
	f = Figure()
	axis = Axis(f[1, 1])
	lines!(axis, as)
	lines!(axis, bs)
	f
end

# ╔═╡ ca31150c-8ffc-4547-8212-c277cc08163b
is_flower_effective(t2, parse(Float64, α))

# ╔═╡ b4ee62b9-9c93-4129-8146-929ac4690d99
t2.x / t2.n

# ╔═╡ 36544591-66ef-4df4-b1b6-728303ed7e7a
confint(t2; level=0.95, tail=:right)

# ╔═╡ fc715704-10a7-45b4-ba01-e2daefd1d5b8
pvalue(t1, tail=:left)

# ╔═╡ 4057976d-a3b2-4ba1-813b-7830c0341a71
pvalue(t2, tail=:left)

# ╔═╡ 03687c67-d14d-480f-b721-3b4598544560
confint(t2, tail=:left)

# ╔═╡ ff70e6d1-df98-4444-ad1c-40ba830ff348
isgood(n, 1000, 0.001, α)

# ╔═╡ e1d0fad7-9657-4085-b8eb-9fa522a70e20
OneSampleZTest(0.004, 0.001)

# ╔═╡ Cell order:
# ╠═5934e838-c887-11eb-3d34-5364828175f3
# ╠═6490f3c9-828c-4a61-a21c-201ca2134772
# ╠═c9739713-12b6-43a7-afe2-6e4fea25b732
# ╠═0ff69784-d617-476d-8793-7d82d8f1ef38
# ╠═b784697f-0644-40ef-97b7-e6fe4af4188e
# ╠═66571363-4357-4de9-b932-2731aa3a6b42
# ╠═909914e4-a7c1-4479-801d-9f92ccefafc4
# ╠═20b53174-e6ab-4035-a1aa-a1ad6a8b100b
# ╠═a0d379a9-75be-4c18-87a3-7410d2bc912c
# ╠═ff5d4c71-b9dd-4028-8c92-3951a4ebcf3c
# ╠═011014c1-ac43-44a8-a358-c9d86ddeb6bf
# ╠═26862094-b78f-4984-89ef-aa25177c0492
# ╠═c09ebe2c-e31a-49fd-9b36-2b653f682db5
# ╠═6d8c724a-cf10-4938-982c-7bff67480260
# ╠═da80c530-f5be-4a52-937b-abbf366fff67
# ╠═5f56093d-3c6f-46a0-85ce-e0f5a6fc792f
# ╠═7c96d734-9876-4215-810a-854afd73d90c
# ╠═9477c96b-8a6b-49c0-8a22-ed91cebf3e30
# ╠═8f252bb5-ae7e-4de3-a956-94ebfc056e1e
# ╠═eb8fbe5e-edf9-452b-a83c-37b8d5258344
# ╠═5445a823-f610-47e0-81da-ee8a302271e1
# ╠═38fb200c-b683-4b02-9341-ecf6d0a3010f
# ╠═d967bfe9-da66-47be-9ecc-469ce324d633
# ╠═daef4589-5ccf-4639-9f0d-4ecc15a1cb90
# ╠═5dfb64de-c28c-4aa7-abca-80933117ce09
# ╠═23956119-4eca-490d-8f4e-bb001ecbdd7d
# ╠═b23c33cf-dffc-4bbd-b088-d51d67ec37df
# ╠═301520f9-1658-4e8a-b39b-7854ee6795d4
# ╠═fd498b55-6d68-4418-8b50-de5cef64931a
# ╠═16375ff7-e018-4948-95c2-5c152afb3d0a
# ╠═b1b25bed-79ac-442a-8c10-985d8d40fdea
# ╠═02eae0af-570f-4a1d-9035-ba9be3efd7ef
# ╠═4068822f-5bd2-4b13-8919-18d5202ba54c
# ╠═1b672c30-d567-4d1f-97e4-e462a314e434
# ╠═740dc4b4-4240-48fa-a164-4097353c48e2
# ╠═ee016a15-a598-451f-94c9-2b19f9c82673
# ╠═2c11fd74-711e-4781-b127-7fa01cfd5ed4
# ╠═eea51e97-9f4e-41b5-b8f4-764e43bcb04f
# ╠═41b5e3d7-5f39-4b55-b6be-3520c76c0924
# ╠═fa49c376-e47c-4089-9d40-f1237c74f749
# ╠═ead4bf05-6319-49aa-bcf9-6a5bb50469ea
# ╠═ec65b6c9-6851-470a-a8cf-1db53e4f143b
# ╠═3df31e23-605d-4833-ae3b-53f1770a487b
# ╠═c0780832-f855-447a-a03b-6327e08261c8
# ╠═9f89b857-9dc2-45b2-a6e4-a9de4ec24370
# ╠═3fa30047-885d-4710-a291-c969ead989c9
# ╠═99b16a23-3eb1-46d4-a4e5-21eab89f3f52
# ╠═8e0ba929-10fd-4586-96e1-28f59490aa69
# ╠═46c9dbc9-6a9e-4393-a251-4b2bd1d7e638
# ╠═3b71c9e7-bd76-4a3a-ba13-e0be6072f417
# ╠═b9d9c8d9-7ad2-4acb-b10f-b69ddd8db2d6
# ╠═7338aa8b-63c8-440f-9e6b-172965b27c23
# ╠═aad68c8f-3575-4d9a-8335-4f1e5339b574
# ╠═6f1630ff-16c9-4721-9707-97fb60479914
# ╠═afd473a4-0aa6-4bed-9f4a-d36ad86d1fa5
# ╠═b8e982f6-a7ea-4031-b971-ce9bf2b0fb88
# ╠═24e13415-cee9-4408-be4f-c00d3f17d01e
# ╠═08f01fc4-f0c0-4a5d-a733-eab8296a1618
# ╠═8a18a998-b6b6-4d30-8132-8a3dfd5260f1
# ╠═78d7cd1c-c05c-497e-a31d-c79efc2e7c2e
# ╠═9446695b-59bf-4d36-bb1b-b66456eb5ac7
# ╠═a4855f8d-9182-4870-ab98-746b89df2017
# ╠═ca31150c-8ffc-4547-8212-c277cc08163b
# ╠═b4ee62b9-9c93-4129-8146-929ac4690d99
# ╠═36544591-66ef-4df4-b1b6-728303ed7e7a
# ╠═fc715704-10a7-45b4-ba01-e2daefd1d5b8
# ╠═4057976d-a3b2-4ba1-813b-7830c0341a71
# ╠═03687c67-d14d-480f-b721-3b4598544560
# ╠═ff70e6d1-df98-4444-ad1c-40ba830ff348
# ╠═e1d0fad7-9657-4085-b8eb-9fa522a70e20
