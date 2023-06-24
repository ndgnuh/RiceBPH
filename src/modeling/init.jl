using ImageFiltering
using Random
using Agents

@doc """
    init_cell_types(map_size::Integer, flower_width::Integer)
    init_cell_types(S::Integer, S_F::Integer)

Returns a [`CellType`](@ref) matrix.
Rice cells' values are $(RiceCell |> Int). 
Flower cells' values are $(FlowerCell |> Int).
""" *
   raw"""
The resulting matrix can be defined by:
```math
\begin{equation}
\left[t_{x,y}\right]_{S \times S}=\left\{ \begin{array}{cl}
0, & y_{a}\le y\le y_{b},\\
1, & \text{otherwise},
\end{array}\right\}, 
\end{equation}
```
where ``y_a`` and ``y_b`` are auxilary variables defined by:
```math
\begin{align}
y_{a} & =\left\lfloor \frac{S-S_{F}}{2}\right\rfloor +\left(S+S_{F}\mod2\right)+1.\\
y_{b} & =S+S_{F}-1.
\end{align}
```
""" *
   """

See also: [`CellType`](@ref).
""" function init_cell_types(
   map_size::Integer, flower_width::Integer
)
   cell_types = fill(RiceCell, map_size, map_size)
   start =
      (map_size - flower_width) ÷ 2 +
      (flower_width + map_size) % 2 +
      1
   for i in start:(start+flower_width-1)
      cell_types[i, :] .= FlowerCell
   end
   return cell_types
end

@doc raw"""
    init_rice_map(S::Integer)

Returns a matrix filled with ``1`` of size ``S \times S``.
```math
\left[e_{x,y}\right]_{S\times S}\equiv1.
```

In code terms, it's basically `ones(Float32, S, S)`.
"""
function init_rice_map(map_size::Integer)
   food = ones(Float32, map_size, map_size)
   return food
end

@doc raw"""
    init_pr_eliminate(init_pr::Float32, cell_types::Matrix{CellType})

Returns `Float32` matrix of elimination probability.
The result matrix is defined by:
```math
\left[p_{x,y}\right]_{S\times S} = P_0 \times (1 - M)) ∗ G(\sigma),
```
where:
- ``G(\sigma)`` is the Gaussian kernel,
- ``P_0`` is the base elimination probability,
- ``M`` is the cell type matrix (see [`init_cell_types`](@ref)).
"""
function init_pr_eliminate(
   init_pr::Float32, cell_types::Matrix{CellType}
)
   σ = (1.0f0 / 0.15f0 - 1.0f0) / 6.0f0
   kernel = Kernel.gaussian(σ)
   pr_eliminate = (@. init_pr * (cell_types == FlowerCell))
   pr_eliminate = imfilter(pr_eliminate, kernel)
   return pr_eliminate
end

"""
    init_properties(parameters::ModelParameters)

Construct a [`ModelProperties`](@ref) from [`ModelParameters`](@ref).
"""
function init_properties(parameters::ModelParameters)
   # unpack
   map_size = parameters.map_size
   flower_width = parameters.flower_width

   # properties
   energy_consume = parameters.energy_transfer / 4.0f0
   rice_map = init_rice_map(map_size)
   cell_types = init_cell_types(map_size, flower_width)

   pr_eliminate_map = init_pr_eliminate(
      parameters.init_pr_eliminate, cell_types
   )
   moving_directions = copy(MOVING_DIRECTIONS)

   # Rice cell marking
   rice_positions = findall(==(RiceCell), cell_types)
   num_rice_cells = length(rice_positions)

   eliminate_positions = [
      idx.I for idx in findall(x -> x > 0, pr_eliminate_map)
   ]

   return ModelProperties(;
      energy_consume,
      moving_directions,
      pr_eliminate_map,
      eliminate_positions,
      rice_map,
      cell_types,
      rice_positions,
      num_rice_cells,
      parameters,
   )
end

"""
    init_positions(rng, position::InitPosition, num_bphs::Integer, map_size::Integer)

Return an iterator over all the initial positions.

See also: `IP_PTS`, `IP_DST`, `InitPosition`.
"""
function init_positions(
   rng,
   position::InitPosition,
   num_bphs::Integer,
   map_size::Integer,
)
   if position == Corner
      xy = wsample(rng, IP_PTS, IP_WEIGHTS, num_bphs * 2)
      points = reshape(xy, 2, num_bphs)
      Iterators.map(Tuple, eachcol(points))
   else
      y = wsample(rng, IP_PTS, IP_WEIGHTS, num_bphs)
      x = rand(rng, 1:map_size, num_bphs)
      zip(y, x)
   end
end

"""
    init_bphs!(model)

Create ``N_I`` agents and put them in the model.
The state variables of agent ``i`` are initialized as follows:
- positions ``x_i, y_i``: sampled from *cumulative* distribution $(show_dist(IP_DST)) with constraint ``x_i \\le $(IP_MAX)`` and ``y_i \\le $(IP_MAX)`` (see [`IP_MAX`](@ref) and [`IP_DST`](@ref)),
- energy ``e_i``: sampler from $(show_dist(normal_range(0, 1))),
- gender ``z^{(g)}_i``: sample from $(show_enum(Gender)) with weight $(show_dist(GENDER_DST)),
- form ``z^{(f)}_i``: sample from $(show_enum(Form)) with weight $(show_dist(FORM_DST)),
- stage ``z^{(s)}_i``: sample from $(show_enum(Stage)) with weight $(show_dist(STAGE_DST)),
- stage countdown ``t^{(s)}_i``: derives from their other state variables,
- reproduction countdown ``t^{(r)}_i``: is the preoviposition countdown if agent is not an adult, else the countdown is either preoviposition countdown or reproduction countdown with equal chances.
"""
function init_bphs!(model)
   parameters = model.parameters
   rng = model.rng

   positions = init_positions(
      rng,
      parameters.init_position,
      parameters.init_num_bphs,
      parameters.map_size,
   )
   energy_dst = normal_range(0.0f0, 1.0f0)
   for pos::Tuple{Int, Int} in positions
      id = nextid(model)
      energy = rand(rng, energy_dst)
      gender = wsample(rng, GENDERS, GENDER_DST)
      form = wsample(rng, FORMS, FORM_DST)
      stage = wsample(rng, STAGES, STAGE_DST)
      stage_cd = randt(
         rng,
         Int16,
         get_stage_countdown(stage, gender, form),
      )
      reproduction_cd = if stage == Adult && rand(rng, Bool)
         randt(rng, Int16, get_reproduction_countdown(form))
      else
         randt(rng, Int16, get_preoviposition_countdown(form))
      end
      agent = BPH(;
         id,
         energy,
         pos,
         gender,
         form,
         stage,
         stage_cd,
         reproduction_cd,
      )
      add_agent_pos!(agent, model)
   end
end

"""
    init_model(; seed::Union{Int, Nothing} = Nothing, kwargs...)

Create and return a ABM model.
Keyword arguments are passed to [`ModelParameters`](@ref).

At the initialization of the model, inferable model properties are calculated
to optimize the runtime of the simulation (see [`init_properties`](@ref)).
This process also create the simulated environment and the vegetation cell state.

After that, the BPH agents are initialized with random states.
After the BPHs are initialized and placed inside the model,
we collect the initial data of interest and store them in the model state.
"""
function init_model(;
   seed::Union{Int, Nothing} = nothing, kwargs...
)
   parameters = ModelParameters(; kwargs...)
   init_model(parameters; seed)
end
function init_model(
   parameters; seed::Union{Int, Nothing} = nothing
)
   #
   # Parameters and properties
   #
   properties = init_properties(parameters)

   #
   # Modele object
   #
   space = GridSpace(
      properties.rice_map |> size; periodic = false
   )
   rng = Xoshiro(seed)
   scheduler = Schedulers.ByProperty(:energy)
   model = AgentBasedModel(
      BPH, space; rng, properties, scheduler
   )

   #
   # Initalize agents
   #
   init_bphs!(model)

   # 
   # First step statistics
   #
   model_action_summarize!(model)

   #
   # Return the model object
   #
   return model
end
