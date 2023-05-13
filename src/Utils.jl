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

export @easy_name_map, @return_if

end
