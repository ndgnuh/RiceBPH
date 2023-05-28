using Flux
using Statistics

"""
Parameterized generalized logistic function

```math
f(t) = A + (1 - A) / (1 + exp(-k(t - t0)))
```
"""
struct Logistic
    A::Vector{Float32}
    k::Vector{Float32}
    t0::Vector{Float32}
end
Flux.@functor Logistic

function Logistic(A::Real = 0.0f0, k::Real = 0.0f0, t0::Real = 0.0f0)
    Logistic([A], [k], [t0])
end

(m::Logistic)(t) = @. m.A + (1 - m.A) / (1 + exp((t - m.t0) * m.k))

function fit_logistic(xs, ys; epochs = 5)
    X = reshape(xs, 1, :)
    Y = reshape(ys, 1, :)
    losses = Float32[]
    t0 = mean(X[findall(Y .== 0.5)])

    optimizer = Flux.Descent(1.0f-5)
    model = Logistic(0, 0, t0)
    optim_state = Flux.setup(optimizer, model)
    for _ in 1:epochs
        loss, grad = Flux.withgradient(model) do m
            Yhat = m(X)
            Flux.Losses.mse(Yhat, Y)
        end
        Flux.update!(optim_state, model, grad[1])
        push!(losses, loss)
    end
    model
end
