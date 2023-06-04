function step_function(t::T) where {T}
    @. t >= 0
end

function step_logistics(t, params)
    step_logistics(t, params...)
end

function step_logistics(t, T1, B1, A2, T2, B2, K2, τ)
    # A1 is K2
    mask = step_function(@. t - τ)
    @. (1 - mask) * logistic(t, K2, T1, B1) + mask * logistic(t, A2, T2, B2, K2)
end

function init_params(::typeof(step_logistics), x, y)
    τ = maximum(x) ÷ 2
    K2, B1, _ = init_params(logistic, x[begin:τ], y[begin:τ])
    A2, _, B2 = init_params(logistic, x[τ:end], y[τ:end])
    T1 = τ / 2.0f0
    T2 = T1 * 3
    return [T1, 0.01, A2, T2, 0.01, K2, τ]
end

function get_param_names(::typeof(step_logistics))
    [:T1, :B1, :A2, :T2, :B2, :K2, :τ]
end
