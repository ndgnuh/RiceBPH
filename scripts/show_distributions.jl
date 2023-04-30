using RiceBPH.Models
using Distributions
using Printf
using DataFrames
using Comonicon

@main function main(; convert_to_day::Bool = false)
    div = convert_to_day ? 24 : 1
    df = DataFrame(name = String[], μ = String[], σ = String[])
    for name in names(Models, all = true)
        value = getproperty(Models, name)
        if value isa Distribution
            push!(df.name, String(name))
            push!(df.μ, @sprintf "%9.4f" value.μ/div)
            push!(df.σ, @sprintf "%9.4f" value.σ/div)
        end
    end
    display(df)
end
