module Visualisations

using DataFrames

include("visualisations/agents.jl")
include("visualisations/recipes.jl")
include("visualisations/presets.jl")

latex_name(name::Symbol) = latex_name(Val(name))
latex_name(name::String) = latex_name(Symbol(name))
latex_name(::Val{:num_init_bphs}) = "N_I"
latex_name(::Val{:num_bphs}) = "n_A"
latex_name(::Val{:num_nymphs}) = "n_N"
latex_name(::Val{:num_eggs}) = "n_E"
latex_name(::Val{:num_brachys}) = "n_B"
latex_name(::Val{:num_macros}) = "n_M"
latex_name(::Val{:pct_rices}) = "r_R"
latex_name(::Val{:pct_nymphs}) = "r_N"
latex_name(::Val{:pct_brachys}) = "r_B"
latex_name(::Val{:pct_macros}) = "r_M"
latex_name(::Val{:energy_transfer}) = "E_T"

end # Visualisations module
