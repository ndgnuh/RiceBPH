using Distributed
@everywhere begin
    using RiceBPH.OFAAT
    using CSV
end

# Bootstrap
@everywhere const envmap = "assets/envmaps/nf-250.csv"

const num_steps = 2880 * 2
const num_replicates = 300
const factor = :energy_transfer
const values = collect(range(start=2.5f-2, stop=2.5f-1, length=10)) |> reverse

# Bootstrap run
OFAAT.run_ofaat!(
    1, 1, factor, values;
    model_data=OFAAT.MODEL_DATA,
    envmap=envmap
)
const result = OFAAT.run_ofaat!(
    num_steps, num_replicates, factor, values;
    model_data=OFAAT.MODEL_DATA,
    envmap=envmap
)
CSV.write("output.csv", result)
