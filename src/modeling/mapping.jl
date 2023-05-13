#
# The stage countdown distribution
#
"""
    get_stage_countdown(stage::Stage, gender::Gender, form::Form)

Return the count down to the next stage of `stage`, depends on the `gender` and `form` of the agent.
"""
function get_stage_countdown(stage::Stage, gender::Gender, form::Form)
    return get_stage_countdown(Val(stage), Val(gender), Val(form))
end

"""
Eggs' stage countdown distribution: $(show_dist(CD_NYMPH)).
"""
function get_stage_countdown(::Val{Egg}, _, _)
    return CD_NYMPH
end

"""
Female nymphs' stage countdown distribution: $(show_dist(CD_F_ADULT)).
"""
function get_stage_countdown(::Val{Nymph}, ::Val{Female}, _)
    return CD_F_ADULT
end

"""
Male nymphs' stage countdown distribution: $(show_dist(CD_M_ADULT)).
"""
function get_stage_countdown(::Val{Nymph}, ::Val{Male}, _)
    return CD_M_ADULT
end

"""
Male adults' stage countdown distribution: $(show_dist(CD_M_DEATH)).
"""
function get_stage_countdown(::Val{Adult}, ::Val{Male}, _)
    return CD_M_DEATH
end

"""
Female macropterous adults' stage countdown distribution: $(show_dist(CD_F_M_DEATH)).
"""
function get_stage_countdown(::Val{Adult}, ::Val{Female}, ::Val{Macro})
    return CD_F_M_DEATH
end

"""
Female brachypterous adults' stage countdown distribution: $(show_dist(CD_F_M_DEATH)).
"""
function get_stage_countdown(::Val{Adult}, ::Val{Female}, ::Val{Brachy})
    return CD_F_B_DEATH
end

"""
Dead stage is just a pending removal at the end of the simulation step, therefore the countdown distribution is just the set ``\\{9999\\}``.
"""
function get_stage_countdown(::Val{Dead}, _, _)
    return (9999,)
end

#
# Mapping current stage to next stage
#
"""
    get_next_stage(stage::Stage)

Return the next age structure of `stage`. See also [`Stage`](@ref).
"""
get_next_stage(stage::Stage) = get_next_stage(Val(stage))

"""
The stage after $(Egg) is $(Nymph).
"""
get_next_stage(::Val{Egg}) = Nymph

"""
The stage after $(Nymph) is $(Adult).
"""
get_next_stage(::Val{Nymph}) = Adult

"""
The stage after $(Adult) is $(Dead).
"""
get_next_stage(::Val{Adult}) = Dead

#
# Reproduction countdown distributions
#
"""
    get_reproduction_countdown(form::Form)

Return the reproduction countdown distribution depends on the agents' form.
"""
get_reproduction_countdown(form::Form) = get_reproduction_countdown(Val(form))

"""
Macropterous's reproduction countdown distribution is $(CD_M_NEXT_REPRODUCE).
"""
get_reproduction_countdown(::Val{Macro}) = CD_M_NEXT_REPRODUCE
"""
Brachypterous's reproduction countdown distribution is $(CD_B_NEXT_REPRODUCE).
"""
get_reproduction_countdown(::Val{Brachy}) = CD_B_NEXT_REPRODUCE

#
# Preoviposition
#
"""
    get_preoviposition_countdown(form::Form)

Return the first-reproduction countdown distribution depends on the agents' form.
"""
function get_preoviposition_countdown(form::Form)
    get_preoviposition_countdown(Val(form))
end

"""
Macropterous's preoviposition distribution is $(CD_M_1ST_REPRODUCE).
"""
function get_preoviposition_countdown(::Val{Macro})
    return CD_M_1ST_REPRODUCE
end

"""
Brachypterous's preoviposition distribution is $(CD_B_1ST_REPRODUCE).
"""
function get_preoviposition_countdown(::Val{Brachy})
    return CD_B_1ST_REPRODUCE
end
