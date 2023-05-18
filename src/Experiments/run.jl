function run(config::ModelVideo)
    model = init_model(config.params; config.seed)
    frames = config.num_steps
    abmvideo(config.video_output, model, agent_step!, model_step!;
             config.framerate, config.spu, frames,
             showstep = true,
             Visualisations.ac,
             Visualisations.heatkwargs,
             Visualisations.heatarray)
    @info "Video written to $(config.video_output)"
end

function run(config::ModelExploration)
    model = init_model(config.params; config.seed)
    fig, _ = abmexploration(model; agent_step!, model_step!,
                            mdata = Models.MDATA_EXPL,
                            Visualisations.ac,
                            Visualisations.heatkwargs,
                            Visualisations.heatarray)
    scene = display(fig)
    wait(scene)
end

function run(config::ModelOFAT)
    # Information from config
    factor = Symbol(config.factor)
    values = eval(Meta.parse(config.values))
    num_replications = config.num_replications
    num_steps = config.num_steps

    result = mapreduce(vcat, values) do value
        @info "Running $(factor) = $(value)"
        # Prepare parameters
        params = Dict(Symbol(k) => v for (k, v) in config.params)
        params[factor] = value

        # Run with each seed
        results = @showprogress pmap(1:num_replications) do seed
            # Init and run
            model = init_model(; params...)
            _, mdf = run!(model, agent_step!, model_step!, num_steps;
                          mdata = Models.MDATA)

            # Populate with factor name and seed
            num_rows = size(mdf, 1)
            mdf[!, factor] = fill(value, num_rows)
            mdf[!, :seed] = fill(seed, num_rows)

            # Without this, oom
            GC.gc()
            return mdf
        end
        agg = reduce(vcat, results)
        return agg
    end

    return result
end
