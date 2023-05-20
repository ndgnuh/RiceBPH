module Utils

"""
    @easy_name_map MyEnum

Overload `Base.convert(::Type{MyEnum}, ::String)` to easily construct
Enum value from `String`.
"""
macro easy_name_map(T)
    namemap = gensym()
    quote
        $namemap = Dict(map(instances($(esc(T)))) do x
                            lowercase(string(x)) => x
                        end)
        function Base.convert(::Type{$(esc(T))}, name::String)
            return $namemap[lowercase(name)]
        end
    end
end

"""
    @return_if(expr)

Expand to `if expr then return end`.
"""
macro return_if(expr)
    quote
        if $(esc(expr))
            return
        end
    end
end

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
latex_name(::Val{:init_pr_eliminate}) = "p_0"
latex_name(::Val{:flower_width}) = "S_F"

export @easy_name_map, @return_if, latex_name

end
