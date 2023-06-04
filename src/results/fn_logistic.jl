function logistic(t, A, T, B, K = 1)
    @. A + (K - A) / (1 + exp((t - T) * B))
end
logistic(t, params) = logistic(t, params...)

function init_params(::typeof(logistic), x, y)
    t0 = mean(x[y .≈ 0.5f0])
    t0 = _legitify(t0, one(eltype(t0)))
    return [0, t0, 0]
end

function get_param_names(::typeof(logistic))
    return [:A, :T, :B]
end
