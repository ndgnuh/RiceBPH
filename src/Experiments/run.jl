function run(config::ModelVideo)
   #
   # Guard to not overwrite the existing
   #
   output = config.video_output
   if isfile(output) || isdir(output)
      @warn "The output path $(output) exists, ignoring. Delete the output to rerun."
      return nothing
   end
   touch(output) # Create to prevent a parallel run

   #
   # Create video
   #
   model = init_model(config.params; config.seed)
   frames = config.num_steps
   abmvideo(
      config.video_output,
      model,
      agent_step!,
      model_step!;
      config.framerate,
      config.spu,
      frames,
      showstep = true,
      Visualisations.ac,
      Visualisations.heatkwargs,
      Visualisations.heatarray,
   )
   @info "Video written to $(output)"
end

function run(config::ModelExploration)
   GLMakie.activate!()
   model = init_model(config.params; config.seed)
   fig, _ = abmexploration(
      model;
      agent_step!,
      model_step!,
      mdata = Models.MDATA_EXPL,
      Visualisations.ac,
      Visualisations.heatkwargs,
      Visualisations.heatarray,
   )
   scene = display(fig)
   wait(scene)
end

function run(config::ModelOFAT)
   #
   # Guard to not overwrite the existing
   #
   output = config.output
   if isfile(output) || isdir(output)
      @warn "The output path $(output) exists, ignoring. Delete the output directory to rerun."
      return nothing
   end
   mkpath(output) # Create to prevent a parallel run

   #
   # Digging information from the config
   #
   factor = Symbol(config.factor)
   values = eval(Meta.parse(config.values))
   num_replications = config.num_replications
   num_steps = config.num_steps

   #
   # Run the OFAT
   #
   result = mapreduce(vcat, values) do value
      @info "Running $(factor) = $(value)"
      # Prepare parameters
      params = Dict(
         Symbol(k) => v for (k, v) in config.params
      )
      params[factor] = value

      # Run with each seed
      results = @showprogress pmap(
         1:num_replications
      ) do seed
         # Init and run
         model = init_model(; params..., seed = seed)
         _, mdf = run!(
            model,
            agent_step!,
            model_step!,
            num_steps;
            mdata = Models.MDATA,
         )

         # Without this, oom
         type_compress!(mdf; compress_float = true)
         GC.gc()
         return mdf
      end
      agg = reduce(vcat, results)
      return agg
   end

   #
   # Store results
   #
   JDF.save(output, result)
end

function run(config::ModelParamScan)
   # Other meta data
   output = config.output
   num_steps = config.num_steps
   num_replications = config.num_replications

   # Look for existing output
   if isfile(output) || isdir(output)
      @warn "The output path $(output) exists, ignoring. Delete the output to rerun."
      return nothing
   end
   mkpath(output) # Create to prevent a parallel run

   # Construct parameter set
   configurations = @chain begin
      (
         Symbol(key) => values for
         (key, values) in config.params
      )
      (
         (key => value for value in values) for
         (key, values) in _
      )
      Iterators.product(_...)
   end

   # Ignore parameters with only one value
   ignores_str = filter(keys(config.params)) do key
      length(unique(config.params[key])) < 2
   end
   ignores = Symbol.(ignores_str)

   # Replicate
   total = length(configurations)
   results = mapreduce(
      vcat, enumerate(configurations)
   ) do (i, params)
      @info "Configuration #$(i)/$(total): $(params)"

      # Run with each seed
      results = @showprogress pmap(
         1:num_replications
      ) do seed
         # Init and run
         model = init_model(; seed = seed, params...)
         _, mdf = run!(
            model,
            agent_step!,
            model_step!,
            num_steps;
            mdata = Models.MDATA,
         )

         # Populate with factor name and seed
         num_rows = size(mdf, 1)
         for (key, value) in params
            if !(key in ignores)
               mdf[!, key] = fill(value, num_rows)
            end
         end
         mdf[!, :seed] = fill(seed, num_rows)

         # Without this, oom
         type_compress!(mdf; compress_float = true)
         GC.gc()
         return mdf
      end
      agg = reduce(vcat, results)
      return agg
   end

   #
   # Store results
   #
   JDF.save(output, results)
   @info "Output written to $(output)"
end
