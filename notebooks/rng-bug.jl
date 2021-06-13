### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# ╔═╡ c79638a6-c80d-11eb-3254-b33f7a382f78
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Random
	using Agents
	using DataFrames
	using ImageFiltering
	using CairoMakie
	using InteractiveDynamics
end

# ╔═╡ 7852fa86-a513-49ac-92b1-7f0a47cedc17
function neighbors_at(n::Integer)
    k = 2 * n + 1
    kern = zeros(Int, k, k)
    center = k ÷ 2 + 1
    dist = map(CartesianIndices(kern)) do I
        i, j = Tuple(I)
        center - (abs(i - center) + abs(j - center))
    end
    dist[center, center] = 0
    map(findall(dist .> 0)) do I
        (I[1] - center, I[2] - center)
    end
end

# ╔═╡ 6ed9031f-8754-46bf-bf92-304d1ea462b8
const default_parameters = (#
    energy_miss=0.025,
    age_init=168,
    age_reproduce=504,
    age_old=600,
    age_die=720,
    pr_reproduce=0.176,
    pr_egg_death=0.0025,
    pr_old_death=0.04,
    offspring_max=12,
    offspring_min=5,
    energy_max=1.0,
    energy_transfer=0.1,
    energy_consume=0.025,
    energy_move=0.2,
    energy_reproduce=0.8,
    move_directions=neighbors_at(2)
)

# ╔═╡ 55d77475-590d-4c21-a47b-2012fba13d8f
Base.@kwdef mutable struct BPH <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float16
    age::Int16
end

# ╔═╡ cc080461-80c3-40cd-bc6e-d1c46f017b9a
function model_step!(model)
	T = eltype(model.food)
    @. model.food = min(model.food + model.food * T(0.008), one(T))
end

# ╔═╡ c7c02074-b970-425a-9586-48aa34e62c27
function agent_step!(agent, model)
    # position
    x, y = agent.pos

    # Older
    agent.age = agent.age + one(agent.age)

    # Step wise energy loss
    agent.energy = agent.energy - (agent.age ≥ model.age_init) * model.energy_consume

    # Move conditionally
    if agent.age ≥ model.age_init && agent.energy ≥ model.energy_move
        walk!(agent, rand(model.rng, model.move_directions), model)
    end

    # Eat conditionally
    if model.food[x, y] > 0 && agent.age ≥ model.age_init
        transfer = min(#
            model.energy_transfer,
            model.food[x, y],
            model.energy_max - agent.energy,
        )
        model.food[x, y] -= transfer
        agent.energy += transfer
    end

    # Reproduce conditionally
    if (
        agent.age ≥ model.age_reproduce && # Old enough
        agent.energy ≥ model.energy_reproduce && # Energy requirement
        rand(model.rng) ≤ model.pr_reproduce # Have RNG Jesus by your side
    )
        nb_offspring = rand(model.rng, (model.offspring_min):(model.offspring_max))
        for _ in 1:nb_offspring
            id = nextid(model)
            agent = BPH(;
                id=id,
                pos=agent.pos,
                energy=0.4,
                age=0,
            )
            add_agent_pos!(agent, model)
        end
        agent.energy -= one(agent.energy) / 10
    end

    # Die conditionally
    if (agent.energy ≤ 0) || # Exausted
       (agent.age ≥ model.age_die) || # Too old
       (rand(model.rng) ≤ model.pr_killed[x, y]) || # killed
       (
           model.age_die > agent.age ≥ model.age_old && # Old
           rand(model.rng) ≤ model.pr_old_death # And weak
       ) ||
       (
           agent.age < model.age_init && # Young
           rand(model.rng) ≤ model.pr_egg_death # And weak
       ) # then
        kill_agent!(agent, model)
        return nothing
    end
    # End of agent step
end

# ╔═╡ a7a6cbab-5b38-42d3-9ede-1e2b5550f2f1
function init_model(; envmap, pr_killed, seed, scheduler, kwargs...)
	nb_bph_init = 200
    rng = MersenneTwister(seed)
    food = collect(transpose(envmap))
    pr_killed = imfilter(isnan.(food) * pr_killed, Kernel.gaussian(2.5))

    # PROPERTIES

    params = merge(default_parameters, kwargs)
    properties = (#
        food=food,
        total_bph=nb_bph_init,
        death_natural=0,
        death_predator=0,
        pr_killed=pr_killed,
        pr_killed_positions=convert.(Tuple, findall(!iszero, pr_killed)),
        energy_full=1.0 - params.energy_transfer,
        params...,
    )

    # MODEL

    space = GridSpace(size(food); periodic=false)
    model = ABM(BPH, space; scheduler=scheduler, properties=properties, rng=rng)

    # AGENTS CREATION
    positions = Iterators.product(1:5, 1:5)
    positions = filter(pos -> !isnan(food[pos...]), collect(positions))
    for _ in 1:nb_bph_init
        bph = BPH(; #
            id=nextid(model),
            pos=rand(model.rng, positions),
            energy=rand(model.rng, 0.4:0.01:0.6),
            age=rand(model.rng, 0:300),
        )
        add_agent_pos!(bph, model)
    end

    # RETURN
    return model
end

# ╔═╡ 79076b76-917f-439c-b954-8046867614c0
heatkwargs=(
	nan_color=RGBAf0(1.0, 1.0, 0.0, 0.5),
	colormap=[RGBAf0(0, 1.0, 0, i) for i in 0:0.01:1],
	colorrange=(0, 1),
)

# ╔═╡ 11b14ef0-3554-498c-8e14-aafd5d026a49
adata, mdata = let food(model) = count(model.food .≥ 0.5), 
	bph(agent) = agent.energy > 0
    [(bph, count)], [food]
end


# ╔═╡ 11362a40-572d-4019-9620-baecb02b01f9
begin
	function envmap(T::Type, d::Integer)
		env = ones(T, 100, 100)
		xstart, xend = (100 - d) ÷ 2, (100 + d) ÷ 2
		env[:, xstart+1:xend] .= convert(T, NaN)
		return env
	end
	envmap(d::Integer) = envmap(Float16, d)
end

# ╔═╡ 6cc30e3d-ca13-4ffb-b623-fcdb7c31936c
function run_and_collect_data(; seed, scheduler)
	model = init_model(; 
		envmap=envmap(20),
		pr_killed=0.075,
		seed=seed,
		scheduler=scheduler)
	adf, mdf = run!(model, agent_step!, model_step!, 2880; 
		adata=adata, mdata=mdata)
	leftjoin(adf, mdf, on=:step)
end

# ╔═╡ fe5717d3-dd4a-470a-82bb-453e9867dc3d
function run_and_collect_data2(; seed, scheduler)
	model = init_model(; 
		envmap=envmap(20),
		pr_killed=0.075,
		seed=seed,
		scheduler=scheduler)
	adata = [:energy]
	adf_, mdf = run!(model, agent_step!, model_step!, 2880; 
		adata=adata, mdata=mdata)
	adf = combine(groupby(adf_, :step), 
		:energy => (energy -> count(x -> x > 0, energy)) => :count_bph)
	leftjoin(adf, mdf, on=:step)
end

# ╔═╡ f1bbd543-4f24-496a-804e-c594ebc22c5c
function run_and_make_video(videopath; seed, scheduler)
	model = init_model(; 
		envmap=envmap(20),
		pr_killed=0.075,
		seed=seed,
		scheduler=scheduler)
	abm_video(videopath, model, agent_step!, model_step!;
		frames=2880,
		framerate=30,
		heatkwargs=heatkwargs,
		heatarray=model -> model.food,
		am=agent -> :circle
	)
	return videopath
end

# ╔═╡ dc557b3a-8f6d-4578-b723-60b8e02a02a7
let kwargs = (seed = rand(1:100), scheduler=Schedulers.randomly)
	df1=run_and_collect_data(;kwargs...)
	df2=run_and_collect_data2(;kwargs...)
	f = Figure()
	a1,a2 = Axis(f[1,1]), Axis(f[1,2])
	lines!(a1, df1.step, df1.count_bph)
	lines!(a1, df2.step, df2.count_bph)
	lines!(a2, df1.step, df1.food)
	lines!(a2, df2.step, df2.food)
	f
end

# ╔═╡ 8674a5e3-805a-4bfe-b8c1-1687a38df04e
let f = Figure()
	a = Axis(f[1,1])
	for seed in 1:20
		df = run_and_collect_data(;seed =seed, scheduler=Schedulers.randomly)
		kwargs = if df.food[end] ≤ df.food[1] ÷ 2
			lines!(a, df.step, df.count_bph; label = "Seed $seed")	
		else
			lines!(a, df.step, df.count_bph;)	
		end
	end
	f[1,2] = Legend(f, a, "Odd things", framevisible = false)
	f
end

# ╔═╡ 46abc4b7-6ed1-4adb-b31e-9973b06ef69d
run_and_make_video("Seed 4.mp4"; seed =4,scheduler = Schedulers.randomly)

# ╔═╡ f6fe4765-7a8f-4c48-907b-539610da783d
let f = Figure()
	a = Axis(f[1,1])
	haslegend = false
	for seed in 1:50
		df = run_and_collect_data(;seed =seed, scheduler=Schedulers.by_id)
		kwargs = if df.food[end] ≤ df.food[1] ÷ 2
			haslegend = true
			lines!(a, df.step, df.count_bph; label = "Seed $seed")	
		else
			lines!(a, df.step, df.count_bph;)	
		end
	end
	if haslegend
		f[1,2] = Legend(f, a, "Odd things", framevisible = false)
	end
	f
end

# ╔═╡ 18eaf72c-ec5f-4f18-9d87-e37415462643
run_and_make_video("Seed44-byid.mp4"; seed =44,scheduler = Schedulers.by_id)

# ╔═╡ 41f6b231-f8cf-46ca-a66f-ada0ce56e8b7
function run_and_make_video2(videopath; seed, scheduler)
    model = init_model(;
        envmap = envmap(20),
        pr_killed = 0.075,
        seed = seed,
        scheduler = scheduler,
    )
    abm_video(
        videopath,
        model,
        agent_step!,
        model_step!;
        frames = 2880,
        framerate = 30,
        heatkwargs = heatkwargs,
        heatarray = model -> model.food,
        am = agent -> :circle,
        scheduler = Schedulers.by_id
    )
    return videopath
end

# ╔═╡ 421492fc-72fc-446a-ba57-c2635065f7e5
run_and_make_video2("Seed4-new.mp4"; seed=4, scheduler=Schedulers.randomly)

# ╔═╡ Cell order:
# ╠═c79638a6-c80d-11eb-3254-b33f7a382f78
# ╠═7852fa86-a513-49ac-92b1-7f0a47cedc17
# ╠═6ed9031f-8754-46bf-bf92-304d1ea462b8
# ╠═55d77475-590d-4c21-a47b-2012fba13d8f
# ╠═cc080461-80c3-40cd-bc6e-d1c46f017b9a
# ╠═c7c02074-b970-425a-9586-48aa34e62c27
# ╠═a7a6cbab-5b38-42d3-9ede-1e2b5550f2f1
# ╠═79076b76-917f-439c-b954-8046867614c0
# ╠═11b14ef0-3554-498c-8e14-aafd5d026a49
# ╠═11362a40-572d-4019-9620-baecb02b01f9
# ╠═6cc30e3d-ca13-4ffb-b623-fcdb7c31936c
# ╠═fe5717d3-dd4a-470a-82bb-453e9867dc3d
# ╠═f1bbd543-4f24-496a-804e-c594ebc22c5c
# ╠═dc557b3a-8f6d-4578-b723-60b8e02a02a7
# ╠═8674a5e3-805a-4bfe-b8c1-1687a38df04e
# ╠═46abc4b7-6ed1-4adb-b31e-9973b06ef69d
# ╠═f6fe4765-7a8f-4c48-907b-539610da783d
# ╠═18eaf72c-ec5f-4f18-9d87-e37415462643
# ╠═41f6b231-f8cf-46ca-a66f-ada0ce56e8b7
# ╠═421492fc-72fc-446a-ba57-c2635065f7e5
