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

function generate_sobol_inputs(method::Sobol, p_range::AbstractVector; samples, kwargs...)
    AB = QuasiMonteCarlo.generate_design_matrices(samples, [i[1] for i in p_range],
                                                  [i[2] for i in p_range],
                                                  QuasiMonteCarlo.SobolSample(),
                                                  2 * method.nboot)
    A = reduce(hcat, @view(AB[1:(method.nboot)]))
    B = reduce(hcat, @view(AB[(method.nboot + 1):end]))
    TA = eltype(A)
    
    # Copied from the first part of gsa function
    d, n = size(A)
    nboot = method.nboot # load to help alias analysis
    n = n ÷ nboot
    multioutput = false
    Anb = Vector{Matrix{TA}}(undef, nboot)
    for i in 1:nboot
        Anb[i] = A[:, (n * (i - 1) + 1):(n * (i))]
    end
    Bnb = Vector{Matrix{TA}}(undef, nboot)
    for i in 1:nboot
        Bnb[i] = B[:, (n * (i - 1) + 1):(n * (i))]
    end
    _all_points = mapreduce(hcat, Anb, Bnb) do (args...)
        GlobalSensitivity.fuse_designs(args...; second_order = 2 in method.order)
    end

    return _all_points
end

function compute_sobol(method, ally, d, n)
    GlobalSensitivity.gsa_sobol_all_y_analysis(
        method,
        ally, d, n, :Jansen1999, nothing, Val(false),
    )
end
