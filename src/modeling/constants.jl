using Distributions
using StatsBase

#
# Cooldowns to X (hours)
#
const CD_NYMPH = normal_hour_range(6, 13)
const CD_F_ADULT = normal_hour_range(11, 16)
const CD_M_ADULT = normal_hour_range(13, 15)
const CD_M_DEATH = normal_hour_range(11, 12)
const CD_F_M_DEATH = normal_hour_range(27, 28)
const CD_F_B_DEATH = normal_hour_range(22, 23)
@doc """
Distribution of cooldown time from one stage to another

"""
CD_NYMPH, CD_F_ADULT, CD_M_ADULT, CD_M_DEATH

#
# Reproduction params
#
const AVG_EGGS_B = 300.7f0
const AVG_EGGS_M = 249.0f0
const MIN_NUM_OFFSPRINGS = 5
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
"""
Stages of BPHs agent, represented by a Int8 value. The stages are:

Stage | Value
--- | ---
`Egg` | $(Int(Egg))
`Nymph` | $(Int(Nymph))
`Adult` | $(Int(Adult))
`Dead` | $(Int(Dead))

Agents with `$(Dead)` stage will be removed at the end of their step.
"""

@enum Gender::Bool Male Female
@enum Form::Bool Brachy Macro
const NEXT_STAGE = Dict(Egg => Nymph, Nymph => Adult, Adult => Dead)
const GENDER_DST = Weights([1.0f0, 1.69f0]) # male / female
const FORM_DST = Weights([13.9f0, 15.4f0]) # brachys / macros
const STAGE_DST = Weights([50.0f0, 70.7f0, 15.4f0 + 13.9f0])
const GENDERS = [Male, Female]
const FORMS = [Brachy, Macro]
const STAGES = [Egg, Nymph, Adult]
# It's a shame we dont have pattern matching yet
const STAGE_CDS = Dict((Egg, Female, Brachy) => CD_NYMPH,
                       (Egg, Female, Macro) => CD_NYMPH,
                       (Egg, Male, Brachy) => CD_NYMPH,
                       (Egg, Male, Macro) => CD_NYMPH,
                       # Nymph cooldown to adult
                       (Nymph, Female, Brachy) => CD_F_ADULT,
                       (Nymph, Female, Macro) => CD_F_ADULT,
                       (Nymph, Male, Brachy) => CD_F_ADULT,
                       (Nymph, Male, Macro) => CD_M_ADULT,
                       # Adult cooldown to death
                       (Adult, Male, Brachy) => CD_M_DEATH,
                       (Adult, Male, Macro) => CD_M_DEATH,
                       (Adult, Female, Brachy) => CD_F_B_DEATH,
                       (Adult, Female, Macro) => CD_F_M_DEATH)
const REPRODUCE_1ST_CDS = Dict(Brachy => CD_B_1ST_REPRODUCE,
                               Macro => CD_M_1ST_REPRODUCE)
const REPRODUCE_CDS = Dict(Brachy => CD_B_NEXT_REPRODUCE,
                           Macro => CD_M_NEXT_REPRODUCE)

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
const IP_MAX = 15
const IP_DST = let dst = Poisson(6)
    [1 - cdf(dst, x) for x in 1:IP_MAX]
end
const IP_PTS = collect(1:IP_MAX)

#
# DATA COLLECTION
#
const MDATA = [:pct_rices, :num_eggs, :num_nymphs, :num_brachys, :num_macros, :num_females]
const MODEL_DATA = MDATA
num_bphs(m) = m.num_nymphs + m.num_brachys + m.num_macros
pct_nymphs(m) = m.num_nymphs / num_bphs(m)
pct_brachys(m) = m.num_brachys / num_bphs(m)
pct_females(m) = m.num_females / num_bphs(m)
const MDATA_EXPL = [:pct_rices, num_bphs, pct_females, pct_nymphs, pct_brachys]

#
# Misc
#
@enum CellType::Bool FlowerCell RiceCell
function Base.convert(::Type{Bool}, celltype::CellType)
    return Bool(celltype)
end
