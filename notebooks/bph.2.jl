### A Pluto.jl notebook ###
# v0.14.5

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

# ╔═╡ a1e77490-ba51-11eb-3cd8-1d82e8b5f7e4
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
end

# ╔═╡ 9bb18432-873d-4979-9e2c-a71e1007b2d7
using Agents, InteractiveDynamics, CairoMakie, PlutoUI

# ╔═╡ f3d42d7d-3e92-4f78-9284-689e2ac50017
using Setfield

# ╔═╡ 6ca2d3d4-d9ac-4e9d-9b1b-e8a66f00c7e6
using Random

# ╔═╡ d4ed1cd4-89a1-49f3-8c18-19215b4c2e8e
using DataFrames

# ╔═╡ 89d0deb2-13c1-45ca-b2ec-ee9704ae6e15
using Base.Threads

# ╔═╡ 3097bf32-e7ba-4b36-8674-3ddd37e1f395
mutable struct BPH <: AbstractAgent
	id::Int
	pos::Dims{2}
	energy
	age
	nb_reproduce
end

# ╔═╡ d073c77d-390c-437b-8ede-630f07e5d9d9
# module MyModel
# using Ag
# @agent BPH GridAgent{2} begin
# 	energy
# 	age
# 	nb_reproduce
# end
# end

# ╔═╡ 4abaea9e-d7ff-4d00-9433-0dd6e3d6da8d
# BPH = MyModel.BPH

# ╔═╡ d948d629-73bc-48b2-9275-51c0bd82a29a
function calculate_positions(pos, nb_flower, field_size)
	positions = if pos === :corner
		Iterators.product(1:5, 1:5)
	elseif pos === :border
		_, field_height = field_size
		Iterators.product(1:2, 1:field_height)
	elseif pos === :random
		field_width, field_height = field_size
		flower_start = (field_width ÷ 2 - nb_flower ÷ 2)
		Iterators.product(1:flower_start, 1:field_height)
	end
	collect(positions)
end

# ╔═╡ 60c02b02-92d3-4c58-b9f1-6e71dfaa28fc
function init_model(nb_bph_init, nb_flower, init_position, field_size;
		energy_miss = 0.025,
		age_init = 168,
		age_reproduce = 504,
		age_old = 600,
		age_die = 720,
		pr_move = 0.99,
		pr_reproduce = 0.07,
		pr_egg_death = 0.0025,
		pr_old_death = 0.04,
		offspring_max = 12,
		offspring_min = 5,
		energy_max = 1.0,
		energy_transfer = 0.1,
		energy_consume = 0.025,
		energy_move = 0.2,
		energy_reproduce = 0.8,
		seed = 1)
	field_width, field_height = field_size
	properties = (
		age_init = 168,
		age_reproduce = 504,
		age_old = 600,
		age_die = 720,
		pr_move = 0.99,
		pr_reproduce = 0.7,
		pr_egg_death = 0.0025,
		pr_old_death = 0.04,
		offspring_max = 12,
		offspring_min = 5,
		energy_miss = 0.025,
		energy_max = 1.0,
		energy_transfer = 0.1,
		energy_consume = 0.025,
		energy_move = 0.2,
		energy_reproduce = 0.8,
		flower_start = field_width ÷ 2 - nb_flower ÷ 2,
		flower_end = field_width ÷ 2 + nb_flower ÷ 2,
		food = fill(0.4, field_size)
	)
	field = GridSpace(field_size; periodic=false)
	rng = MersenneTwister(seed)
	scheduler = Schedulers.randomly
	model = ABM(BPH, field; properties, rng, scheduler)
	
	init_positions = calculate_positions(init_position, nb_flower, field_size)
	for _ in 1:nb_bph_init
		id = nextid(model)
		pos = rand(model.rng, init_positions)
		energy = rand(model.rng, 0.4:0.01:0.6)
		bph = BPH(id, pos, energy, rand(model.rng, 0:299), rand(model.rng, 1:21))
		add_agent_pos!(bph, model)
	end
	
	return model
end

# ╔═╡ cca251da-24fe-4b97-87db-337cc2d9490d
function bph_reflex!(bph, model)
	# older
	bph.age = bph.age + 1
	
	# move around
	directions = Iterators.product([-1, -2, 1, 2], [-1, -2, 1, 2])
	if bph.age > model.age_init && rand(model.rng) < model.pr_move
		walk!(bph, rand(model.rng, directions |> collect), model)
	end
	
	# loss energy normally
	if bph.age ≥ model.age_init
		bph.energy = bph.energy - model.energy_consume
	end
	
	# loss energy in flower
	x, y = bph.pos
	if model.flower_start ≤ x < model.flower_end
		bph.energy -= model.energy_miss
	elseif model.food[x, y] > 0 && bph.age ≥ model.age_init
		transfer = min(model.energy_transfer, model.food[x, y])
		model.food[x, y] -= transfer
		bph.energy = min(bph.energy + transfer, model.energy_max)
	end
	
	# reproduce
	if (bph.age ≥ model.age_reproduce && 
		bph.energy ≥ model.energy_reproduce &&
		bph.nb_reproduce < 21 &&
		rand(model.rng) ≤ model.pr_reproduce)
		# 
		bph.nb_reproduce = bph.nb_reproduce + 1
		nb_offspring = rand(model.rng, model.offspring_min:model.offspring_max)
		for _ in 1:nb_offspring
			id = nextid(model)
			bph = BPH(id, bph.pos, 0.4, 0, 0)
			add_agent_pos!(bph, model)
		end
	end
	
	# die
	if bph.energy ≤ 0 || 
			(bph.age ≥ model.age_die) ||
			(model.age_die ≥ bph.age ≥ model.age_old && rand(model.rng) ≤ model.pr_old_death) 
			(bph.age < model.age_init && rand(model.rng) ≤ model.pr_egg_death)
		kill_agent!(bph, model)
	end
end

# ╔═╡ af4042f1-7679-4cc5-ad20-b23937ffa40b
function rice_grow!(model)
	alive = @. model.food > 0
	@. model.food = min(model.food + model.food * 0.008 * alive , 1.0)
end

# ╔═╡ e8c37ce6-9376-4215-ae47-a3e3df26276a
bph_color(bph) = if bph.age < 168
	RGBf0(0, 0, 255)
else
	RGBf0(255, 0, 0)
end

# ╔═╡ 7e042ab7-6d6e-4df0-a9ef-b521fdf9f1de
rice_color(model) = map(positions(model)) do pos
	x, y = pos
	if model.flower_start ≤ x ≤ model.flower_end
		# RGBf0(255, 255, 0)
		-1
	else
		# RGBAf0(0, 255, 0, model.food[x, y])
		max(model.food[x, y], 0)
	end
end

# ╔═╡ 9ff14f09-e64b-4898-935a-c425ef1d3eaf
plotkwargs = (ac = bph_color, heatarray = rice_color)

# ╔═╡ 456e997d-c424-4647-9ba9-cd98a4c43ed2
heatkwargs = (nan_color = RGBf0(1.0, 1.0, 0),
	colormap = [RGBAf0(0, 1.0, 0, i) for i in 0:0.01:1]
)

# ╔═╡ 6f4dc104-c0f1-4c9f-af54-5de98a6e62e9
md"""
Generate Video $(@bind should_video PlutoUI.CheckBox()) 

Collect Data $(@bind should_data PlutoUI.CheckBox()) 

Flower $(@bind flower PlutoUI.Slider(12:20; show_value=true))
"""

# ╔═╡ 2da972ea-1e4b-4096-81b2-1e86b4eb4a10
@bind seed PlutoUI.NumberField(1:2000)

# ╔═╡ 48fb77fb-ab35-4a4b-948b-ce3599f7ec60
if should_video
	vid = "bph.mp4"
	let model = init_model(200, flower, :corner, (100, 100); seed = seed)
		abm_video(vid, model, bph_reflex!, rice_grow!; frames=1200 - 1, framerate=10, heatkwargs, plotkwargs...)
		LocalResource(vid)
	end
end

# ╔═╡ 149636d6-95b3-4ead-a607-f37c4de5ed52
1234

# ╔═╡ f0ddf1cc-12e5-4444-a5f4-d4085b8056b3
# @time max_times = map(1:100) do seed
# 	bph(x) = true
# 	model = init_model(200, 16, :corner, (100, 100); seed = seed)
# 	adf, _ = run!(model, bph_reflex!, rice_grow!, 2880; adata = [(bph, count)])
# 	seed => maximum(adf.step)
# end

# ╔═╡ 9e235da3-3f0f-42de-af15-10d940b3304c
@bind rerun_btn PlutoUI.Button("Re-run")

# ╔═╡ 3492f6a0-a867-4403-b32f-4dff1f706142
begin
	rerun_btn
	model = init_model(200, flower, :corner, (100, 100); seed)
end

# ╔═╡ 063e3c58-fb8f-46d7-8f37-677af66598bf
md"## Run & Collect data"

# ╔═╡ 09cf52d0-d6f5-4dad-ad43-68aea0f44cdd
# adata = [x -> x.pos, x -> x.age]

# ╔═╡ 736ae5e6-3c3f-4e24-9b93-6fc578d378db
adata = let bph_A1(bph) = bph.age ≥ model.age_init && bph.pos[1] < model.flower_start
	bph_E1(bph) = bph.age < model.age_init && bph.pos[1] < model.flower_start
	bph_A2(bph) = bph.age ≥ model.age_init && bph.pos[1] ≥ model.flower_end
	bph_E2(bph) = bph.age < model.age_init && bph.pos[1] ≥ model.flower_end
	[(bph_E1, count), (bph_E2, count), (bph_A1, count), (bph_A2, count)]
end

# ╔═╡ ff33a882-4092-42e5-a272-043cc9c2dbf0
# max_step = maximum(adfa.step)

# ╔═╡ bc177477-8bb5-4821-9076-517b07c0c0f7
# GC.gc()

# ╔═╡ 6835bd93-4824-4768-a575-912fdc4a94ee
let model = init_model(200, flower, :random, (100, 100))
	GC.gc()
	PlutoUI.with_terminal() do
		@time run!(model, bph_reflex!, rice_grow!, 2880; adata=adata);
	end
end

# ╔═╡ 8a7027e6-7959-43e9-b0b6-245ffbeeec74
adf, mdf = run!(model, bph_reflex!, rice_grow!, 2880; adata=adata);

# ╔═╡ 85e8ab56-3345-4e31-a6f0-cff58c42ac6c
# adf2 = rename(adf, [:step, :id, :pos, :age]);

# ╔═╡ 1471bab5-baab-48f3-8f13-975b2aabcd7b
adf

# ╔═╡ 4a9553e5-9229-47ec-8248-e72be094fa34


# ╔═╡ 088a6bab-0be7-4f0e-96bf-7497b6dd7209
let f = Figure()
	Axis(f[1, 1])
	step = adf.step[adf.count_bph_A1 .> 0]
	bph1 = adf.count_bph_A1[adf.count_bph_A1 .> 0]
	lines!(step, bph1)
	lines!(adf.step ./ 24, adf.count_bph_A1)
	lines!(adf.step ./ 24, adf.count_bph_A2)
	f
end

# ╔═╡ 96336b96-44d5-4356-ab9d-ab8cbd9ea1bb
let f = Figure()
	Axis(f[1, 1])
	@threads for seed = 1:5
		model = init_model(20, 18, :corner, (100, 100); seed = seed);
		adf, mdf = run!(model, bph_reflex!, rice_grow!, 2880; adata=adata);
		bph1 = adf.count_bph_A1[1:1700]
		steps = adf.step[1:1700]
		lines!(steps, bph1)
		# lines!(adf.step ./ 24, adf.count_bph_A1)
		# lines!(adf.step ./ 24, adf.count_bph_A2)
	end
	f
end

# ╔═╡ 67366c81-42fd-407c-bf21-1fe04cc4dda0
# adfa = let adult(age) = age .≥ model.age_init
# 	egg(age) = age .< model.age_init
# 	field1(pos) = getindex.(pos, 1) .< model.flower_start
# 	field2(pos) = getindex.(pos, 1) .≥ model.flower_end
# 	combine(groupby(adf2, :step),
# 		[:pos, :age] => ((p, a) -> count(egg(a) .& field1(p))) => :e1,
# 		[:pos, :age] => ((p, a) -> count(adult(a) .& field1(p))) => :a1,
# 		[:pos, :age] => ((p, a) -> count(egg(a) .& field2(p))) => :e2,
# 		[:pos, :age] => ((p, a) -> count(adult(a) .& field2(p))) => :a2,
# 	)
# end;

# ╔═╡ 5a8a235a-64ff-41a3-981b-684a1424fa07
# let f = Figure()
# 	Axis(f[1, 1])
# 	# lines!(adfa.step / 24, adfa.e1)
# 	# lines!(adfa.step / 24, adfa.e2)
# 	lines!(adfa.step, adfa.a1)
# 	lines!(adfa.step, adfa.a2)
# 	f
# end

# ╔═╡ d6502588-0196-4953-86f0-5244b519f9ee


# ╔═╡ Cell order:
# ╠═a1e77490-ba51-11eb-3cd8-1d82e8b5f7e4
# ╠═9bb18432-873d-4979-9e2c-a71e1007b2d7
# ╠═f3d42d7d-3e92-4f78-9284-689e2ac50017
# ╠═3097bf32-e7ba-4b36-8674-3ddd37e1f395
# ╠═d073c77d-390c-437b-8ede-630f07e5d9d9
# ╠═4abaea9e-d7ff-4d00-9433-0dd6e3d6da8d
# ╠═d948d629-73bc-48b2-9275-51c0bd82a29a
# ╠═60c02b02-92d3-4c58-b9f1-6e71dfaa28fc
# ╠═6ca2d3d4-d9ac-4e9d-9b1b-e8a66f00c7e6
# ╠═3492f6a0-a867-4403-b32f-4dff1f706142
# ╠═cca251da-24fe-4b97-87db-337cc2d9490d
# ╠═af4042f1-7679-4cc5-ad20-b23937ffa40b
# ╠═e8c37ce6-9376-4215-ae47-a3e3df26276a
# ╠═7e042ab7-6d6e-4df0-a9ef-b521fdf9f1de
# ╠═9ff14f09-e64b-4898-935a-c425ef1d3eaf
# ╠═456e997d-c424-4647-9ba9-cd98a4c43ed2
# ╠═48fb77fb-ab35-4a4b-948b-ce3599f7ec60
# ╠═6f4dc104-c0f1-4c9f-af54-5de98a6e62e9
# ╠═2da972ea-1e4b-4096-81b2-1e86b4eb4a10
# ╠═149636d6-95b3-4ead-a607-f37c4de5ed52
# ╠═f0ddf1cc-12e5-4444-a5f4-d4085b8056b3
# ╟─9e235da3-3f0f-42de-af15-10d940b3304c
# ╟─063e3c58-fb8f-46d7-8f37-677af66598bf
# ╠═09cf52d0-d6f5-4dad-ad43-68aea0f44cdd
# ╠═736ae5e6-3c3f-4e24-9b93-6fc578d378db
# ╠═ff33a882-4092-42e5-a272-043cc9c2dbf0
# ╠═bc177477-8bb5-4821-9076-517b07c0c0f7
# ╠═6835bd93-4824-4768-a575-912fdc4a94ee
# ╠═8a7027e6-7959-43e9-b0b6-245ffbeeec74
# ╠═d4ed1cd4-89a1-49f3-8c18-19215b4c2e8e
# ╠═85e8ab56-3345-4e31-a6f0-cff58c42ac6c
# ╠═1471bab5-baab-48f3-8f13-975b2aabcd7b
# ╠═4a9553e5-9229-47ec-8248-e72be094fa34
# ╠═088a6bab-0be7-4f0e-96bf-7497b6dd7209
# ╠═89d0deb2-13c1-45ca-b2ec-ee9704ae6e15
# ╠═96336b96-44d5-4356-ab9d-ab8cbd9ea1bb
# ╠═67366c81-42fd-407c-bf21-1fe04cc4dda0
# ╠═5a8a235a-64ff-41a3-981b-684a1424fa07
# ╠═d6502588-0196-4953-86f0-5244b519f9ee
