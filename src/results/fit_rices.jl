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

function fit_rices(
   result::SimulationResult, groupkey = result.seed_factors; gc = false
)
   df::DataFrame = result.df
   groups = groupby(df, groupkey)
   total = length(groups)
   pbar = Progress(total, "Fitting rice")

   combine(groups) do g
      g = sort(g, :step)

      # Last rice
      pct_rices = g.pct_rices[end]
      T_max = g.step[end]

      # Prepare function
      f = RiceLogistic(pct_rices, T_max)
      params = [1.0f0, 0.5f0]

      # Fitting
      x = g.step * 1.0f0
      y = g.pct_rices * 1.0f0
      fit = try
         curve_fit(f, x, y, params)
      catch
         (param = [NaN32, NaN32], converged = false)
      end

      spd_rices = fit.converged ? first(fit.param) : NaN32

      # GC just to be sure
      # Julia has this habit of GC lazily and only after reduction
      next!(pbar)
      GC.gc(false)
      return (; pct_rices, spd_rices)
   end
end

function fit_rice(steps, pct_rice)
   params = [1.0f0, 0.5f0] # Lavenberg-Marquardt doesn't need super good initial
   f = RiceLogistic(pct_rice[end], maximum(steps))
   x = steps * 1.0f0
   y = pct_rice * 1.0f0
   f, curve_fit(f, x, y, params)
end

struct PwLogistic
   A2::Float32
   L2::Float32
   T0::Int
   Tmax::Int
end

function (f::PwLogistic)(t, param)
   A2, L2, T0, Tmax = f.A2, f.L2, f.T0, f.Tmax
   t = @. t / Tmax
   T0 = T0 / Tmax
   B, T1, T2 = param

   # Continous condition
   w1 = 1 + exp(B * (T0 - T1))
   w2 = 1 + exp(B * (T0 - T2))
   A1 = ((A2 + (L2 - A2) / w2) * w1 - 1) / (w1 - 1 + 1e-6)

   # Pieces
   mask = @. t < T0
   s1 = @. A1 + (1 - A1) / (1 + exp(B * (t - T1)))
   s2 = @. A2 + (L2 - A2) / (1 + exp(B * (t - T2)))
   @. mask * s1 + (1 - mask) * s2
end

function fit_rice_pw(steps, pct_rice)
   # Find T0 
   min_T = minimum(steps)
   max_T = maximum(steps)
   q1_T = trunc(Int, (max_T - min_T) * 0.25)
   q3_T = trunc(Int, (max_T - min_T) * 0.75)
   T0 = argmin(abs.(diff(pct_rice[q1_T:q3_T]))) + q1_T
   L2 = pct_rice[T0]
   A2 = pct_rice[end]

   # Starting parameters
   # Lavenberg-Marquardt doesn't need super good initial
   # so this is good enough
   B = 1.0f0
   T1, T2 = 0.25f0, 0.75f0
   params = [B, T1, T2]

   # Fit data
   f = PwLogistic(A2, L2, T0, max_T)
   x = steps * 1.0f0
   y = pct_rice * 1.0f0
   f, curve_fit(f, x, y, params)
end

function fit_rice_auto(steps, pct_rice)
   # Fit both, returns which ever with smaller errors
   f1, fit1 = fit_rice(steps, pct_rice)
   f2, fit2 = fit_rice_pw(steps, pct_rice)
   r1 = sum(fit1.resid)
   r2 = sum(fit2.resid)
   if r1 < r2
      return f1, fit1
   else
      return f2, fit2
   end
end
