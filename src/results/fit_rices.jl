using DataFrames
using LsqFit

struct RiceLogistic
    A::Float32
    T_max::Float32
end

function (f::RiceLogistic)(t, params)
    B, T = params
    A = f.A
    t = t / f.T_max
    @. A + (1 - A) / (1 + exp(B * (t - T)))
end

function get_param_basenames(_::RiceLogistic)
    return [:spd_rices, :T]
end

function fit_rices(result::SimulationResult, groupkey=result.seed_factors)
    df::DataFrame = result.df
    combine(groupby(df, groupkey)) do g
        g = sort(g, :step)

        # Last rice
        pct_rices = g.pct_rices[end]
        T_max = g.step[end]

        # Prepare function
        f = RiceLogistic(pct_rices, T_max)
        params = [1f0, 0.5f0]

        # Fitting
        x = g.step * 1f0
        y = g.pct_rices * 1f0
        fit = try
            curve_fit(f, x, y, params)
        catch
            (param = [NaN32, NaN32], converged=false)
        end

        spd_rices = fit.converged ? first(fit.param) : NaN32
        return (; pct_rices, spd_rices)
    end
end
