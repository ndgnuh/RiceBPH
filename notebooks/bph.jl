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

# ╔═╡ 4abaea9e-d7ff-4d00-9433-0dd6e3d6da8d
using ImageFiltering

# ╔═╡ 6ca2d3d4-d9ac-4e9d-9b1b-e8a66f00c7e6
using Random

# ╔═╡ 480eb153-33b5-4e77-a79b-7ee4368b1ecd
using Base.Threads

# ╔═╡ 2c37c953-0666-4daf-944f-70605730422e
using Dates

# ╔═╡ d4ed1cd4-89a1-49f3-8c18-19215b4c2e8e
using DataFrames

# ╔═╡ 3097bf32-e7ba-4b36-8674-3ddd37e1f395
mutable struct BPH{T} <: AbstractAgent
	id::Int
	pos::Dims{2}
	energy::T
	age::Int
	nb_reproduce::Int
end

# ╔═╡ 15ab4149-b620-4ef0-a658-51bcaa303200
function gencrop(rng = MersenneTwister())
	flower_position = [31:35; 61:65]
	[
		begin
			if x in flower_position || y in flower_position
					NaN
			else
			    one(NaN)
			end
		end for (x, y) in Iterators.product(1:100, 1:100)
	];
end

# ╔═╡ 51ca01ca-eb28-406e-a1c2-14f0ec2d7d40
crop = gencrop()

# ╔═╡ c3eee131-4edc-42d5-a13a-cc461d4da8cf
heatmap(crop; colorrange=(0, 1), colormap=RGBAf0.(0.0, 1.0, 0.0, 0:0.01:1.0), nan_color=RGBAf0(1.0, 1.0, 0., 0.5))

# ╔═╡ b04996a9-b45e-4d2f-8c69-bb8106144838
function calculate_death_pr(crop, pr)
	T = eltype(crop)
	death_pr = zeros(T, size(crop))
	flowers = findall(isnan, crop)
	death_pr[flowers] .= one(T) * convert(T, pr)
	death_pr = imfilter(death_pr, Kernel.gaussian(3))
	death_pr = death_pr / maximum(death_pr) * convert(T, pr)
end

# ╔═╡ f890f694-07e2-4afe-b6c3-14193a373331
death_pr = calculate_death_pr(crop, 0.1)

# ╔═╡ 700835b5-0a48-4cc1-8c06-84fe49b3953f
maximum(death_pr)

# ╔═╡ dd5ab1c5-4cb4-4d06-b333-8463ac1b2d39
heatmap(death_pr; colorrange=(0, 1))

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
function init_model(nb_bph_init, init_position, foodgen, pr_killed;
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
	

	rng = MersenneTwister(seed)
	food = foodgen(rng)
	field_size = size(food)
	field_width, field_height = field_size
	field = GridSpace(field_size; periodic=false)
	
	
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
		# flower_start = field_width ÷ 2 - nb_flower ÷ 2,
		# flower_end = field_width ÷ 2 + nb_flower ÷ 2,
		food = food,
		pr_killed = calculate_death_pr(food, pr_killed),
	)
	
	scheduler = Schedulers.randomly
	model = ABM(BPH, field; properties, rng, scheduler)
	
	# init_positions = calculate_positions(init_position, nb_flower, field_size)
	init_positions = Iterators.product(1:10, 1:10) |> collect
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
	
	# will die if get caught by natural predator
	# regardless if inside flower or not
	x, y = bph.pos
	if rand(model.rng) < model.pr_killed[x, y]
		kill_agent!(bph, model)
		return
	end
	
	# if there's food then eat it
	if model.food[x, y] > 0 && bph.age ≥ model.age_init
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
		return
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

# ╔═╡ 994ed3e6-794b-4b21-804e-154a93be6c57
convert(Float32, NaN)

# ╔═╡ 7e042ab7-6d6e-4df0-a9ef-b521fdf9f1de
rice_color(model) = map(positions(model)) do pos
	model.food[pos...]
end

# ╔═╡ 9ff14f09-e64b-4898-935a-c425ef1d3eaf
plotkwargs = (ac = bph_color, heatarray = rice_color)

# ╔═╡ 456e997d-c424-4647-9ba9-cd98a4c43ed2
heatkwargs = (nan_color = nan_color=RGBAf0(1.0, 1.0, 0., 0.5),
	colormap = [RGBAf0(0, 1.0, 0, i) for i in 0:0.01:1],
	colorrange=(0, 1)
)

# ╔═╡ 94c715f7-f5f1-44f5-86a7-480813051f1c
function vidname(p)
	"bph-pr-killed-$(p).mp4"
end

# ╔═╡ b14c6da8-11d3-489e-80a3-038742feb237
# if batch_video
# 	for pr in 0.22:0.02:0.31
# 		@info "Simulation with death pr = $pr"
# 		start_time = time()
# 		crop = convert.(Float32, gencrop())
# 		pr_killed = convert.(Float32, calculate_death_pr(crop, pr))
# 		model = init_model(200, flower, :corner, crop, pr_killed; seed = seed)
# 		abm_video(vidname(pr), model, bph_reflex!, rice_grow!; frames=2880, framerate=30, heatkwargs, plotkwargs...)
# 		end_time = time()
# 		@info "Done. Process time: $((end_time - start_time) / 60) minute(s)"
# 	end
# end

# ╔═╡ 6f4dc104-c0f1-4c9f-af54-5de98a6e62e9
md"""
Generate Video $(@bind should_video PlutoUI.CheckBox()) 

Batch video $(@bind batch_video PlutoUI.CheckBox())

Collect Data $(@bind should_data PlutoUI.CheckBox()) 

Flower $(@bind flower PlutoUI.Slider(12:20; default=16, show_value=true))
"""

# ╔═╡ 2da972ea-1e4b-4096-81b2-1e86b4eb4a10
@bind seed PlutoUI.NumberField(1:2000)

# ╔═╡ 48fb77fb-ab35-4a4b-948b-ce3599f7ec60
if should_video
	vid = "bph2.mp4"
	let model = init_model(200, flower, :corner, crop, death_pr; seed = seed)
		# try
			abm_video(vid, model, bph_reflex!, rice_grow!; frames=2880, framerate=20, heatkwargs, plotkwargs...)
		# catch e
		# 	@warn e
		# end	
		LocalResource(vid)
	end
end

# ╔═╡ 1f0e0c24-3e60-46cd-84da-15d9bfb450a6
if batch_video
	for pr in 0.32:0.02:0.41
		@info "Simulation with death pr = $pr"
		start_time = time()
		crop = convert.(Float32, gencrop())
		pr_killed = convert.(Float32, calculate_death_pr(crop, pr))
		model = init_model(200, flower, :corner, crop, pr_killed; seed = seed)
		abm_video(vidname(pr), model, bph_reflex!, rice_grow!; frames=2880, framerate=30, heatkwargs, plotkwargs...)
		end_time = time()
		@info "Done. Process time: $((end_time - start_time) / 60) minute(s)"
	end
end

# ╔═╡ 149636d6-95b3-4ead-a607-f37c4de5ed52
1234

# ╔═╡ 9e235da3-3f0f-42de-af15-10d940b3304c
@bind rerun_btn PlutoUI.Button("Re-run")

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
mdata = let food(x) = count(x -> x > 0.50, x.food)
	[food]
end

# ╔═╡ 6835bd93-4824-4768-a575-912fdc4a94ee
adf, mdf = let crop = convert.(Float32, gencrop())
	pr = 0.18
	bph(x) = true
	pr_killed = convert.(Float32, calculate_death_pr(crop, pr))
	model = init_model(200, :corner, gencrop, pr; seed = seed)
	adf, mdf = @time run!(model, bph_reflex!, rice_grow!, 2880; adata = [(bph, count)], mdata = mdata)
end

# ╔═╡ 7d5e6766-8162-4072-ab3c-6665c8083d1a
lines(adf.step, adf.count_bph)

# ╔═╡ fedb969d-95a6-44a3-b00e-26f62de4d811
lines(mdf.step, mdf.food)

# ╔═╡ 8a7027e6-7959-43e9-b0b6-245ffbeeec74
# adf, mdf = run!(model, bph_reflex!, rice_grow!, 2880; adata=adata);

# ╔═╡ 088a6bab-0be7-4f0e-96bf-7497b6dd7209
# let f = Figure()
# 	Axis(f[1, 1])
# 	step = adf.step[adf.count_bph_A1 .> 0]
# 	bph1 = adf.count_bph_A1[adf.count_bph_A1 .> 0]
# 	lines!(step, bph1)
# 	# lines!(adf.step ./ 24, adf.count_bph_A1)
# 	# lines!(adf.step ./ 24, adf.count_bph_A2)
# 	f
# end

# ╔═╡ 89d0deb2-13c1-45ca-b2ec-ee9704ae6e15
# using Base.Threads

# ╔═╡ bea39459-085b-448f-aa00-a5d0935f9dbb
md"""
Plot 1000 ADF: $(@bind plot1000BPH PlutoUI.CheckBox())

Plot 1000 Rice: $(@bind plot1000Rice PlutoUI.CheckBox())
"""

# ╔═╡ c15be8ec-1a5e-4fd6-87a8-eba54c12920b
pr = 0.2

# ╔═╡ 4ad97925-3e68-48db-ad97-6e7c281ed136


# ╔═╡ 96336b96-44d5-4356-ab9d-ab8cbd9ea1bb
if plot1000BPH
	let f = Figure()
		Axis(f[1, 1])
		lk = ReentrantLock()
		for seed = 1:1000
			
			bph(x) = true
			local model = init_model(200, :corner, gencrop, pr; seed = seed)
			local adf, _ = @time run!(model, bph_reflex!, rice_grow!, 2880; adata = [(bph, count)], mdata=mdata)
			@info "seed $seed is done"
			lines!(adf.step, adf.count_bph)
		end
		f
	end
end

# ╔═╡ 90446f93-37ad-4a75-8201-a6d11048a247
if plot1000Rice
	let f = Figure()
		Axis(f[1, 1])
		lk = ReentrantLock()
		for seed = 1:1000
			#local pr = 0.1
			bph(x) = true
			local model = init_model(200, :corner, gencrop, pr; seed = seed)
			local _, mdf = @time run!(model, bph_reflex!, rice_grow!, 2880; adata = [(bph, count)], mdata=mdata)
			@info "seed $seed is done"
			lines!(mdf.step, mdf.food)
		end
		f
	end
end

# ╔═╡ 162777d1-23b6-4a23-a9dc-a46345769f3b
heatmap(calculate_death_pr(gencrop(), 0.15))

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
# ╠═4abaea9e-d7ff-4d00-9433-0dd6e3d6da8d
# ╠═51ca01ca-eb28-406e-a1c2-14f0ec2d7d40
# ╠═15ab4149-b620-4ef0-a658-51bcaa303200
# ╠═c3eee131-4edc-42d5-a13a-cc461d4da8cf
# ╠═b04996a9-b45e-4d2f-8c69-bb8106144838
# ╠═f890f694-07e2-4afe-b6c3-14193a373331
# ╠═700835b5-0a48-4cc1-8c06-84fe49b3953f
# ╠═dd5ab1c5-4cb4-4d06-b333-8463ac1b2d39
# ╠═d948d629-73bc-48b2-9275-51c0bd82a29a
# ╠═60c02b02-92d3-4c58-b9f1-6e71dfaa28fc
# ╠═6ca2d3d4-d9ac-4e9d-9b1b-e8a66f00c7e6
# ╠═cca251da-24fe-4b97-87db-337cc2d9490d
# ╠═af4042f1-7679-4cc5-ad20-b23937ffa40b
# ╠═e8c37ce6-9376-4215-ae47-a3e3df26276a
# ╠═994ed3e6-794b-4b21-804e-154a93be6c57
# ╠═7e042ab7-6d6e-4df0-a9ef-b521fdf9f1de
# ╠═9ff14f09-e64b-4898-935a-c425ef1d3eaf
# ╠═456e997d-c424-4647-9ba9-cd98a4c43ed2
# ╠═48fb77fb-ab35-4a4b-948b-ce3599f7ec60
# ╠═480eb153-33b5-4e77-a79b-7ee4368b1ecd
# ╠═2c37c953-0666-4daf-944f-70605730422e
# ╠═94c715f7-f5f1-44f5-86a7-480813051f1c
# ╠═b14c6da8-11d3-489e-80a3-038742feb237
# ╠═1f0e0c24-3e60-46cd-84da-15d9bfb450a6
# ╠═6f4dc104-c0f1-4c9f-af54-5de98a6e62e9
# ╠═2da972ea-1e4b-4096-81b2-1e86b4eb4a10
# ╠═149636d6-95b3-4ead-a607-f37c4de5ed52
# ╟─9e235da3-3f0f-42de-af15-10d940b3304c
# ╟─063e3c58-fb8f-46d7-8f37-677af66598bf
# ╠═09cf52d0-d6f5-4dad-ad43-68aea0f44cdd
# ╠═736ae5e6-3c3f-4e24-9b93-6fc578d378db
# ╠═ff33a882-4092-42e5-a272-043cc9c2dbf0
# ╠═6835bd93-4824-4768-a575-912fdc4a94ee
# ╠═7d5e6766-8162-4072-ab3c-6665c8083d1a
# ╠═fedb969d-95a6-44a3-b00e-26f62de4d811
# ╠═8a7027e6-7959-43e9-b0b6-245ffbeeec74
# ╠═d4ed1cd4-89a1-49f3-8c18-19215b4c2e8e
# ╠═088a6bab-0be7-4f0e-96bf-7497b6dd7209
# ╠═89d0deb2-13c1-45ca-b2ec-ee9704ae6e15
# ╠═bea39459-085b-448f-aa00-a5d0935f9dbb
# ╠═c15be8ec-1a5e-4fd6-87a8-eba54c12920b
# ╠═4ad97925-3e68-48db-ad97-6e7c281ed136
# ╠═96336b96-44d5-4356-ab9d-ab8cbd9ea1bb
# ╠═90446f93-37ad-4a75-8201-a6d11048a247
# ╠═162777d1-23b6-4a23-a9dc-a46345769f3b
# ╠═67366c81-42fd-407c-bf21-1fe04cc4dda0
# ╠═5a8a235a-64ff-41a3-981b-684a1424fa07
# ╠═d6502588-0196-4953-86f0-5244b519f9ee
