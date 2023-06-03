function step_function(t::T) where {T}
    @. t >= 0 ? one(T) : zero(T)
end

function step_logistics(t, params)
    step_logistics(t, params...)
end

function step_logistics(t, A1, A2, T1, T2, K1, K2, τ)
    mask = step_function(@. t - τ)
    (1 - mask) .* logistic(t, A1, T1, K1) .+ mask .* logistic(t, A2, T2, K2)
end

function get_param_names(::typeof(step_logistics))
    [:A1, :A2, :T1, :T2, :K1, :K2, :τ]
end
