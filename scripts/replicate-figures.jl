using RiceBPH.Results: Result, visualize_qcv, compute_observations, visualize_num_bphs
using GLMakie

function main()
    # Prepare
    figdir = "figures"
    mkpath(figdir)

    # Fix num init bphs plots
    result = Result("outputs/num-init-bphs/")
    fig = visualize_num_bphs(result)
    output_file = joinpath(figdir, "param-fix-num-init-bphs.png")
    save(fig, output_file)
    @info "Figure written to $output_file"

    #  result
    results = ("outputs/energy-transfer/",
               "outputs/num-init-bphs/",
               "outputs/init-pr-eliminate/",
               "outputs/flower-width/")
    for result_folder in results
        @info "Processing $result_folder"
        result = Result(result_folder)
        df = compute_observations(result)

        # Stability analysis plots
        fig, _, _ = visualize_qcv(result, df)
        output_file = joinpath(figdir, "stability-$(result.factor_name).png")
        save(output_file, fig)
        @info "Figure written to $output_file"
        GC.gc()
    end
end

main()
