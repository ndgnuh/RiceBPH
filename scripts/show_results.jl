using RiceBPH.Results
using Comonicon
using CSV

@main function main(result::String;
                    preset::Union{Int, Nothing} = nothing,
                    output::Union{String, Nothing} = nothing,
                    stable_steps::Bool = false)
    df = Results.load(result)
    formatted = Results.show_analysis(df, preset; stable_steps)

    display(formatted)
    if !isnothing(output)
        CSV.write(formatted, output)
        @info "Output has been written to $output"
    end
end
