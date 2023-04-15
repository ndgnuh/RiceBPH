@kwdef mutable struct MovingAVG{F}
    k::Int
    data::Vector{F}
    count::Int = 0
end


function stream_moving_average(T::Type, k::Integer)
    MovingAVG(k, fill(one(T), k), 0)
end


function Base.push!(ma::MovingAVG, x)
    if ma.count < ma.k
        ma.count += 1
        circshift!(ma.data, 1)
        ma.data[1] = x
        x
    else
        xn = (sum(ma.data) + x) / (ma.k + 1)
        circshift!(ma.data, 1)
        ma.data[1] = xn
        xn
    end
end


function Base.collect(ma::MovingAVG)
    sum(ma.data[begin:begin+ma.count-1]) / ma.count
end
