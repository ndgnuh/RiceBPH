using Distributed
using Comonicon
using CSV
using RiceBPH.OFAAT: run_ofaat!
using TOML

#= const num_steps = 2880 * 2 =#
#= const num_replicates = 300 =#
#= const map_size = 250 =#
#= const flower_width = 0 =#
#= const init_pr_eliminate = 0.0f0 =#
#= const num_init_bphs = 200 =#
#= const factor = :energy_transfer =#
#= const values = collect(range(start = 2.5f-2, stop = 2.5f-1, length = 10)) |> reverse =#

# Bootstrap run
@main function main(config_file::String; output::String = "output.csv")
    config = TOML.parsefile(config_file)
    options = Dict(Symbol(k) => v for (k, v) in config)
    @info options

    factor = Symbol(pop!(options, :factor))
    values = range(; start = pop!(options, :value_start),
                   stop = pop!(options, :value_stop),
                   length = pop!(options, :num_values))
    num_steps = pop!(options, :num_steps)
    num_replicates = pop!(options, :num_replicates)
    result = run_ofaat!(num_steps, num_replicates, factor, values; options...)
    CSV.write(output, result)
end
