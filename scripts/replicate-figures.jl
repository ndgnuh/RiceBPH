using RiceBPH.Results:
   Result,
   visualize_qcv,
   compute_observations,
   visualize_num_bphs,
   visualize_pct_nymphs
using CairoMakie

const px_per_unit = 3

function main()
   # Prepare
   figdir = "figures"
   mkpath(figdir)
   update_theme!(;
      fonts = (;
         regular = "fonts/NewComputerModern/NewCM10-Regular.otf",
         bold = "fonts/NewComputerModern/NewCM10-Bold.otf",
      ),
   )

   # Fix num init bphs plots
   result = Result("outputs/num-init-bphs/")
   fig = visualize_num_bphs(result)
   output_file = joinpath(
      figdir, "param-fix-num-init-bphs.png"
   )
   save(output_file, fig; px_per_unit)
   @info "Figure written to $output_file"
   result = nothing
   GC.gc()

   # Fix energy transfer plot
   result = Result("outputs/energy-transfer/")
   fig = visualize_pct_nymphs(result)
   output_file = joinpath(
      figdir, "param-fix-energy-transfer.png"
   )
   save(output_file, fig; px_per_unit)
   @info "Figure written to $output_file"
   result = nothing
   GC.gc()

   #  result
   results = (
      "outputs/energy-transfer/",
      "outputs/num-init-bphs/",
      "outputs/init-pr-eliminate/",
      "outputs/flower-width/",
   )
   for result_folder in results
      @info "Processing $result_folder"
      result = Result(result_folder)
      df = compute_observations(result)
      GC.gc()

      # Stability analysis plots
      fig = visualize_qcv(result, df)
      output_file = joinpath(
         figdir, "stability-$(result.factor_name).png"
      )
      save(output_file, fig; px_per_unit)
      @info "Figure written to $output_file"
      GC.gc()
   end
end

main()
