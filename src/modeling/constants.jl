using Distributions
using StatsBase
using ..Utils: @easy_name_map

#
# Cooldowns to X (hours)
#
const CD_NYMPH = normal_hour_range(6, 13)
const CD_F_ADULT = normal_hour_range(11, 16)
const CD_M_ADULT = normal_hour_range(13, 15)
const CD_M_DEATH = normal_hour_range(11, 12)
const CD_F_M_DEATH = normal_hour_range(27, 28)
const CD_F_B_DEATH = normal_hour_range(22, 23)

#
# Reproduction params
#
@doc "Average total number of eggs (truncate winged form)"
const AVG_EGGS_B = 300.7f0

@doc "Average total number of eggs (fully winged form)"
const AVG_EGGS_M = 249.0f0

@doc "Minimum number of eggs per reproduction"
const MIN_NUM_OFFSPRINGS = 5

@doc "Maximum number of eggs per reproduction"
const MAX_NUM_OFFSPRINGS = 12

const CD_B_1ST_REPRODUCE = normal_hour_range(0.8f0, 6.8f0)
const CD_M_1ST_REPRODUCE = normal_hour_range(4.4f0, 10.4f0)
const CD_B_NEXT_REPRODUCE = normal_range(CD_F_B_DEATH.μ / AVG_EGGS_B *
                                         MIN_NUM_OFFSPRINGS,
                                         CD_F_B_DEATH.μ / AVG_EGGS_B *
                                         MAX_NUM_OFFSPRINGS)
const CD_M_NEXT_REPRODUCE = normal_range(CD_F_M_DEATH.μ / AVG_EGGS_M *
                                         MIN_NUM_OFFSPRINGS,
                                         CD_F_M_DEATH.μ / AVG_EGGS_M *
                                         MAX_NUM_OFFSPRINGS)
@info CD_B_NEXT_REPRODUCE
const DST_NUM_OFFSPRINGS = normal_range(MIN_NUM_OFFSPRINGS, MAX_NUM_OFFSPRINGS)

#
# Population structure
#
@enum Stage::Int8 Egg Nymph Adult Dead
@easy_name_map Stage
@enum Gender::Bool Male Female
@easy_name_map Gender
@enum Form::Bool Brachy Macro
@easy_name_map Form
const GENDER_DST = Weights([1.0f0, 1.69f0]) # male / female
const FORM_DST = Weights([13.9f0, 15.4f0]) # brachys / macros
const STAGE_DST = Weights([50.0f0, 70.7f0, 15.4f0 + 13.9f0, 0])
const GENDERS = collect(instances(Gender))
const FORMS = collect(instances(Form))
const STAGES = collect(instances(Stage))

const MOVING_DIRECTIONS = let speed = 2
    moving_range = (-speed):speed
    square_radius = speed^2 + speed^2
    [(dx, dy)
     for (dx, dy) in Iterators.product(moving_range, moving_range)
     if (dx^2 + dy^2) <= square_radius][:]
end

#
# INIT POSITION
# sample with probability 1 - cdf(Poi, x)
# 5 cells ≈ 1m in length
#
@enum InitPosition::Bool Corner Border
"""
The maximum initial positions. 15 cells is approximately equivalent to 2.25 meters.
"""
const IP_MAX = 15

@doc raw"""
Initial position distribution.
The initial distribution is a Poisson distribution with ``\lambda = 6``.
"""
const IP_DST = Poisson(6)
const IP_WEIGHTS = [1 - cdf(IP_DST, x) for x in 1:IP_MAX]

"""
Possible initial positions index.
"""
const IP_PTS = collect(1:IP_MAX)

#
# DATA COLLECTION
#
"""
Indicates which data to be appeared in the final results.
This constant is for replications.
The data to be collected is all the statistics in the [`ModelProperties`](@ref).
"""
const MDATA = [:pct_rices, :num_eggs, :num_nymphs, :num_brachys, :num_macros, :num_females]

"""
Alias for [`MDATA`](@ref).
"""
const MODEL_DATA = MDATA

num_bphs(m) = m.num_nymphs + m.num_brachys + m.num_macros
pct_nymphs(m) = m.num_nymphs / num_bphs(m)
pct_brachys(m) = m.num_brachys / num_bphs(m)
pct_females(m) = m.num_females / num_bphs(m)
@doc raw"""
Same as [`MDATA`](@ref), but collect other metrics.
This is used in model exploration.
It collects ``r_R`` from [`ModelProperties`](@ref) and some other custom metrics, such as:
- total number of BPHs (does not include eggs) ``n_{\text{BPH}}``,
- percentage of nymphs ``r_{N}``,
- percentage of females ``r_{F}``,
- percentage of truncate-winged form BPHs ``r_{B}``,
- percentage of fully-winged form BPHs ``r_M``.

```math
\begin{align}
n_{\text{BPH}} & =n_{E}+n_{B}+n_{M},\\
r_{E} & =\left(n_{E}+1\varepsilon\right)/\left(n_{\text{BPH}}+3\varepsilon\right),\\
r_{B} & =\left(n_{B}+1\varepsilon\right)/\left(n_{\text{BPH}}+3\varepsilon\right)\\
r_{M} & =\left(n_{M}+1\varepsilon\right)/\left(n_{\text{BPH}}+3\varepsilon\right)
\end{align}
```
"""
const MDATA_EXPL = [:pct_rices, num_bphs, pct_females, pct_nymphs, pct_brachys]

#
# Misc
#
@enum CellType::Bool FlowerCell RiceCell
function Base.convert(::Type{Bool}, celltype::CellType)
    return Bool(celltype)
end

#
# Documentations for enums
#
"""
The enum `CellType` is based on `Bool` values, indicates a cell is
a rice cell or flower cell:

Value        | Bool                  | Int
---          | ---                   | ---
`FlowerCell` | `$(Bool(FlowerCell))` | $(Int(FlowerCell))
`RiceCell`   | `$(Bool(RiceCell))`   | $(Int(RiceCell))
"""
CellType, FlowerCell, RiceCell

@doc """
Distribution of cooldown time from one stage to another. See [](@ref constants).
"""
CD_NYMPH, CD_F_ADULT, CD_M_ADULT, CD_M_DEATH, CD_F_M_DEATH, CD_F_B_DEATH

@doc """
Stages of BPHs agent, represented by a Int8 value. The stages are:

Stage   | Value         | Represents
:---    | :---          | :---
`Egg`   | $(Int(Egg))   | BPH's eggs
`Nymph` | $(Int(Nymph)) | BPHs in nymph stage
`Adult` | $(Int(Adult)) | BPHs in adult stage
`Dead`  | $(Int(Dead))  | BPHs in adult stage but their time runs out

Agents with `$(Dead)` stage will be removed at the end of their step.
See also: [`get_next_stage`](@ref)
"""
Stage, Egg, Nymph, Adult

@doc """
The gender of BPH agent. This enum is `Bool` based.

Value    | Int              | Bool
:---     | :---             | :---
`Male`   | `$(Int(Male))`   | `$(Bool(Male))`
`Female` | `$(Int(Female))` | `$(Bool(Female))`
"""
Gender, Male, Female

@doc """
The form of BPH agent. This enum is `Bool` based.

Value    | Bool              | Description
:---     | :---              | :---
`Brachy` | `$(Bool(Brachy))` | The truncate-winged form
`Macro`  | `$(Bool(Macro))`  | The fully-winged form
"""
Form, Macro, Brachy

@doc """
BPH Initialization position.

Value    | Description
:---     | :---
`Corner` | 1meters at a corner of the map
`Border` | 1 meters along a border of the map, the border does not overlap with flower

See also [`IP_DST`](@ref).
"""
InitPosition, Corner, Border
