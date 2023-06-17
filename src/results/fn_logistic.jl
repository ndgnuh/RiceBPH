function logistic(t, A, B, T, K = 1)
   t = t / 1000
   @. A + (K - A) / (1 + exp(B * (t - T)))
end
logistic(t, params) = logistic(t, params...)

function init_params(::typeof(logistic), x, y)
   t0 = mean(x[y.≈0.5f0])
   t0 = _legitify(t0, one(eltype(t0)))
   return [0, t0, 0]
end

function get_param_basenames(::typeof(logistic))
   return [:pct_rices, :spd_rices, :T]
end

function get_param_masks(::typeof(logistic))
   return [true, true, false]
end
