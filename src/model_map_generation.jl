using Base.Iterators
using Base: @kwdef
using LinearAlgebra

abstract type TilingType end

@kwdef struct HorizontalTile <: TilingType
    size::Int
    number::Int
end

@kwdef struct GridTile <: TilingType
    xsize::Int
    ysize::Int
    xnumber::Int
    ynumber::Int
end

"""
```
calc_tile_indices(size::Int, tile_size::Int, number::Int)
```

Return the indices for NaN elements to be tiled inside a matrix.

## Parameters

- `size`: The total lenght size
- `tile_size`: The width of a single tile
- `number`: The number of tiles
"""
function calc_tile_indices(size::Int, tile_size::Int, number::Int)
    # size = number * tile_size + (number + 1) * remain_size
    remain_size = (size - number * tile_size) ÷ (number + 1)
    aux1 = countfrom(remain_size, remain_size + tile_size)
    aux2 = takewhile(<=(size - tile_size), aux1)
    return map(x -> x:(x + tile_size - 1), aux2)
end

"""
    calc_tile_indices(size::Int, tile::HorizontalTile)

Short hand for `calc_tile_indices(size, tile.size, tile.number)`
"""
function calc_tile_indices(size::Int, tile::HorizontalTile)
    return calc_tile_indices(size, tile.size, tile.number)
end

"""
    tile_nan!(M::Matrix, tile::TilingType)

Returns `M` after filling `M` with `NaN` values in the positions defined by `tile`.
"""
function tile_nan!(M::Matrix{T}, tile::HorizontalTile) where {T<:AbstractFloat}
    height = size(M)[2]
    indices = calc_tile_indices(height, tile.size, tile.number)
    for idx in indices
        M[:, idx] .= convert(T, NaN)
    end
    return M
end

function tile_nan!(M::Matrix{T}, tile::GridTile) where {T<:AbstractFloat}
    width, height = size(M)[2]
    htile = HorizontalTile(; size=tile.xsize, number=tile.xnumber)
    vtile = HorizontalTile(; size=tile.ysize, number=tile.ynumber)
    generate_map!(M, htile)
    transpose!(M)
    generate_map!(M, vtile)
    return transpose!(M)
end

"""
```
generate_rice_matrix(sz::Tuple{Int, Int}, tile::TilingType)
generate_rice_matrix(::Type{<:AbstractFloat}, sz::Tuple{Int, Int}, tile::TilingType)
```
Returns a matrix of size `sz` which filled with `NaN` at positions
specified by `tile`. By default, the matrix is `Float32`.
"""
function generate_map(T::Type{<:AbstractFloat}, sz, tile::TilingType)
    M = ones(T, sz)
    return tile_nan!(M, tile)
end
function generate_map(sz, tile::TilingType)
    return generate_map(Float32, sz, tile)
end
