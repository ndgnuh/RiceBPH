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

# ╔═╡ ba49db2e-cb57-11eb-0b6d-95ae95c35719
begin
	using Pkg
	Pkg.activate("..")
	using GradProject
	using InteractiveDynamics
	using CairoMakie
end

# ╔═╡ 03c3bbc0-f91d-4e91-b2c7-dbcd28eceaed
using PlutoUI

# ╔═╡ ecd1ccd8-fc7f-4577-aec9-f6ac0442ee87
using DelimitedFiles

# ╔═╡ f834aec9-676e-4161-b275-6488f9a5ffd2
using Statistics

# ╔═╡ 8e1f5590-b7b6-4b2c-a3b1-1ec573e25a1f
Model = GradProject.Model

# ╔═╡ 93a151a3-a978-44a4-b93e-b3f3916a202a
function ac(model)
    return function (agent)
        if isnan(model.food[agent.pos...])
            return RGBf0(0, 0, 0)
        elseif agent.age < model.age_init
            "#FF0000"
        else
           	"#0000FF"
        end
    end
end


# ╔═╡ ccfcd584-f319-44cd-9220-e0f2af9fe736
const heatkwargs=(
			nan_color=RGBAf0(1, 1, 0.270588),
			colormap=[RGBAf0(0.270588, 1, 0.270588, i) for i in 0:0.01:1],
			colorrange=(0, 1),
		)

# ╔═╡ 47b279c9-19fd-4095-87f4-c477f10c4d47
function plotkwargs(model)
	(
		ac=ac(model),
		am=Model.am,
		heatarray=Model.heatarray,
		resolution=(1200,1200),
		heatkwargs=heatkwargs
	)
end

# ╔═╡ aa6ada26-a723-4198-b5c9-78e8481bc46c
base = joinpath("/tmp", "snapshot")

# ╔═╡ 686d5e42-6834-4290-9bc8-14497d399ce7
@bind seed PlutoUI.Slider(1:1000, show_value=true)

# ╔═╡ 76bc81a3-ec4f-4763-9f2d-ec31a8fa1f68
function init_model()
	model = Model.init_model(; 
		envmap="../src/maps/019-1x2.csv",
		nb_bph_init=200,
		init_position=:corner,
		pr_killed=0.05,
		seed = seed
	)
end

# ╔═╡ 9b197d84-be93-4929-92a5-ad350e405435
names = let model = init_model()
	rm(base, recursive=true, force=true)
	mkpath(base)
	kw = plotkwargs(model)
	map(0:250:2880) do i
		fig, _ = abm_plot(model; kw...)
		Model.run!(model, Model.agent_step!, Model.model_step!, 300)
		name = joinpath(base, "$i.png")
		save(name, fig) 
		name
	end
end

# ╔═╡ 47ed7f95-97af-4e0c-9e5e-1c1ea48e51b8
@bind plt PlutoUI.Select(reverse(names), default=names[end-1])

# ╔═╡ b9d81098-7130-4159-8f83-029d28cec1cc
LocalResource(plt)

# ╔═╡ 31fd3ba1-e3ec-4e9a-a79c-4aca3a0d33f0
collect(0:250:2880) |> clipboard

# ╔═╡ 36ec99d4-7d51-4c7d-bab3-270b2cf14eb7
map1x2 = readdlm("../src/maps/019-1x2.csv")

# ╔═╡ 48d8ee85-7b31-43f6-a492-e1858a625bfc
heatmapkwargs = (zauto=true, transpose=true, showscale=false)

# ╔═╡ bd8e91af-d793-42a1-863a-81ce019b06f4
p = CairoMakie.heatmap(transpose(map1x2); resolution=(1200,1200), heatkwargs...)

# ╔═╡ 18a1bc29-8202-4a42-8ce0-811d88ddc8bc
save("/tmp/map1x2.png", p, resolution=(1200, 1200))

# ╔═╡ 21843312-1ead-4982-9f72-1302f96001e4
LocalResource("/tmp/map1x2.png")

# ╔═╡ a4cfa06f-ce3d-4931-89d2-86db58b26333
adf = let model = init_model()
	adf, _ = Model.run!(model, Model.agent_step!, Model.model_step!, 2880, adata=Model.adata)
	adf
end

# ╔═╡ 2672bbdc-a564-44a5-8fc4-f7208243b969
let f = lines(adf.step / 24, adf.count_bph)
	save("/tmp/bph-count-before.png", f)
	f
end

# ╔═╡ 7abc52f1-1a81-4bc8-ac2c-adf383f72a6e
begin
	function ma(X, k)
		pad = zeros(eltype(X), k ÷ 2)
		[pad; [mean(X[i:(i+k)]) for i in 1:length(X) - k]; pad]
	end
	function proc(X; thres=0)
		X = ma(X, 24 * 7 ÷ 2)
		X = (X .- mean(X)) ./ std(X)
		@. X ≥ thres
	end
end

# ╔═╡ 0565bd26-81af-4740-9d9c-fc878fdde641
let f = lines(adf.step / 24, proc(adf.count_bph))
	save("/tmp/bph-count-after.png", f)
	f
end

# ╔═╡ e995b7fa-f2e7-4e85-8e54-b741057652d1
let f = Figure()
	a = Axis(f[1,1])
	b = Axis(f[1,2])
	CairoMakie.lines!(a, adf.step / 24, adf.count_bph)
	lines!(b, adf.step / 24, proc(adf.count_bph))
	f
end

# ╔═╡ Cell order:
# ╠═ba49db2e-cb57-11eb-0b6d-95ae95c35719
# ╠═8e1f5590-b7b6-4b2c-a3b1-1ec573e25a1f
# ╠═76bc81a3-ec4f-4763-9f2d-ec31a8fa1f68
# ╠═93a151a3-a978-44a4-b93e-b3f3916a202a
# ╠═ccfcd584-f319-44cd-9220-e0f2af9fe736
# ╠═47b279c9-19fd-4095-87f4-c477f10c4d47
# ╠═aa6ada26-a723-4198-b5c9-78e8481bc46c
# ╠═9b197d84-be93-4929-92a5-ad350e405435
# ╠═03c3bbc0-f91d-4e91-b2c7-dbcd28eceaed
# ╟─686d5e42-6834-4290-9bc8-14497d399ce7
# ╠═47ed7f95-97af-4e0c-9e5e-1c1ea48e51b8
# ╠═b9d81098-7130-4159-8f83-029d28cec1cc
# ╠═31fd3ba1-e3ec-4e9a-a79c-4aca3a0d33f0
# ╠═ecd1ccd8-fc7f-4577-aec9-f6ac0442ee87
# ╠═36ec99d4-7d51-4c7d-bab3-270b2cf14eb7
# ╠═48d8ee85-7b31-43f6-a492-e1858a625bfc
# ╠═bd8e91af-d793-42a1-863a-81ce019b06f4
# ╠═18a1bc29-8202-4a42-8ce0-811d88ddc8bc
# ╠═21843312-1ead-4982-9f72-1302f96001e4
# ╠═a4cfa06f-ce3d-4931-89d2-86db58b26333
# ╠═f834aec9-676e-4161-b275-6488f9a5ffd2
# ╠═2672bbdc-a564-44a5-8fc4-f7208243b969
# ╠═0565bd26-81af-4740-9d9c-fc878fdde641
# ╠═e995b7fa-f2e7-4e85-8e54-b741057652d1
# ╠═7abc52f1-1a81-4bc8-ac2c-adf383f72a6e
