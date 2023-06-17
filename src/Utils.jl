module Utils
using LaTeXStrings

"""
    @easy_name_map MyEnum

Overload `Base.convert(::Type{MyEnum}, ::String)` to easily construct
Enum value from `String`.
"""
macro easy_name_map(T)
   namemap = gensym()
   quote
      $namemap = Dict(
         map(instances($(esc(T)))) do x
            lowercase(string(x)) => x
         end,
      )
      function Base.convert(::Type{$(esc(T))}, name::String)
         return $namemap[lowercase(name)]
      end
      function Base.tryparse(
         ::Type{$(esc(T))}, name::String
      )
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
         return nothing
      end
   end
end

function latex_name(name::Symbol)
   try
      latexstring(latex_name(Val(name)))
   catch _
      return String(name) # Just return 
   end
end
latex_name(name::String) = latex_name(Symbol(name))
latex_name(::Val{:num_init_bphs}) = raw"N_{\text{init}}"
latex_name(::Val{:num_bphs}) = raw"n_{\text{BPH}}"
latex_name(::Val{:num_nymphs}) = "n_N"
latex_name(::Val{:num_eggs}) = "n_E"
latex_name(::Val{:num_brachys}) = "n_B"
latex_name(::Val{:num_macros}) = "n_M"
latex_name(::Val{:pct_rices}) = raw"r_{\text{rices}}"
latex_name(::Val{:spd_rices}) = raw"{\beta}_{\text{rices}}"
latex_name(::Val{:pct_nymphs}) = raw"r_{\text{nymphs}}"
latex_name(::Val{:pct_brachys}) = raw"r_{\text{brachys}}"
latex_name(::Val{:pct_macros}) = raw"r_{\text{macros}}"
latex_name(::Val{:energy_transfer}) = "E_T"
latex_name(::Val{:init_pr_eliminate}) = "p_0"
latex_name(::Val{:flower_width}) = raw"S_{\text{flower}}"
latex_name(::Val{:first_peak}) = raw"t_{\text{peak}}"
latex_name(::Val{:num_peaks}) = raw"n_{\text{peak}}"

export @easy_name_map, @return_if, latex_name

end
