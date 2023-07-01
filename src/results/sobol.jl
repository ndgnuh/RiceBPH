function groupmean(df, xcond, yname; output_column = nothing)
    result = combine(groupby(df, xcond)) do subgroup
            (; E = mean(subgroup[!, yname]))
    end
    if !isnothing(output_column)
        rename!(result, :E => output_column)
    end
    return result
end


function groupvar(df, xcond, yname; output_column = nothing)
    result = combine(groupby(df, xcond)) do subgroup
            (; V = var(subgroup[!, yname]))
    end
    if !isnothing(output_column)
        rename!(result, :V => output_column)
    end
    return result
end


function sobol(df, xnames, yname)
    # result df
    num_factors = length(xnames)
    base::DataFrame = select(df, Cols(xnames..., yname))
    
    
    corrected = false
    S1 = zeros(Float32, num_factors)
    S2 = zeros(Float32, num_factors, num_factors)
    St = zeros(Float32, num_factors)
    V = var(base[!, yname]; corrected)
    V1 = zeros(Float32, num_factors)
    V2 = zeros(Float32, num_factors, num_factors)
    
    # First order
    for (i, xi) in enumerate(xnames)
        # E[Y | X_i ]
        cm = groupmean(base, xi, yname; output_column=:E)
        V1[i] = var(cm.E; corrected)
        S1[i] = V1[i] / (V + 1e-12)
    end
    
    if num_factors > 1
        # Second order
        product = Iterators.product
        for ((i, xi), (j, xj)) in product(enumerate(xnames), enumerate(xnames))
            if i >= j
                continue
            end
            cond = [xi, xj]
            cm = groupmean(df, cond, yname; output_column=:E)
            V2[i, j] = var(cm.E; corrected) - V1[i] - V2[j]
            S2[i, j] = V2[i, i] / (V + 1e-12)
        end
    end
    
    # Total effect index
    for (i, xi) in enumerate(xnames)
        cond = setdiff(xnames, [xi])
        cv = groupvar(df, cond, yname, output_column=:V)
        St[i] = mean(cv.V) / V
    end
    
    return S1, S2, St
end


using QuasiMonteCarlo
using GlobalSensitivity

function generate_sobol_inputs(samples, p_range)
    A, B = QuasiMonteCarlo.generate_design_matrices(
        samples, 
        [i[1] for i in p_range],
        [i[2] for i in p_range],
        QuasiMonteCarlo.SobolSample(),
        2
    )
    n, d = size(A)
    allx = GlobalSensitivity.fuse_designs(A, B, second_order=true)
    return (allx, n, d)
end

function compute_sobol(ally, n, d, second_order=true)
    method = second_order ? Sobol(order=[0, 1, 2]) : Sobol(order=[0,1])
    GlobalSensitivity.gsa_sobol_all_y_analysis(
                                               method, ally, n, d, :Jansen1999, nothing, Val(false))
end
