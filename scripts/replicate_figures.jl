using RiceBPH.Results
using RiceBPH.Results:
   SimulationResult,
   Result,
   visualize_qcv,
   compute_observations,
   visualize_num_bphs,
   visualize_pct_nymphs
using CairoMakie
using Distributions
import RiceBPH.Results as R
import RiceBPH.Experiments as E

const px_per_unit = 3

function plot_sobol_sa(figdir)
   configs = (
      E.SOBOL_ET,
      E.SOBOL_ET_WIDE,
      E.SOBOL_N0,
      E.SOBOL_FLOWER_P0,
      E.SOBOL_FLOWER_P0_WIDE,
   )

   # Sobol figure1
   for config in configs
      # Load result and input names
      result = SimulationResult(config.output)
      input_names = result.factors
      num_inputs = length(input_names)

      # Compute obseration
      df = R.compute_observations(result)

      # Plot for each parameters
      for name in input_names
         # Output path
         outputpath = basename(config.output)
         outputpath = if num_inputs > 1
            "phase-$(outputpath)-$(name).png"
         else
            "phase-$(outputpath).png"
         end
         outputpath = joinpath(figdir, outputpath)

         # Draw figure
         fig = R.draw_phase(df, name)

         # Save
         save(outputpath, fig; px_per_unit)
         @info "Output written to $outputpath"
      end

      # If multiple inputs
      if num_inputs == 2
         outputpath = basename(config.output)
         outputpath = "phase-$(outputpath).png"
         outputpath = joinpath(figdir, outputpath)
         fig = R.draw_phase_2f(
            df, result.factors..., :pct_rices
         )
         save(outputpath, fig; px_per_unit)
         @info "Output written to $outputpath"
      end
   end
end

function plot_geom(p)
   dist = Geometric(p)
   x = 0:30
   axis = (;
      ylabel = L"p_n",
      yticks = 0:0.01:p,
      xticks = -minimum(x)-2:2:maximum(x)+2,
      xlabel = "count",
      xlabelsize = 24,
      ylabelsize = 24,
      titlesize = 22,
      title = L"\mathrm{Geo}(%$p)",
   )
   scatterlines(x, pdf.(dist, x); axis)
end

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
   CairoMakie.activate!()

   # Geometric distribution
   let output = joinpath(figdir, "geom.png")
      save("geom.png", plot_geom(0.15f0); px_per_unit = 3)
      @info "Figure saved to $(output)"
   end

   # Fix num init bphs plots
   result = SimulationResult("outputs/scan-num-init-bphs/")
   fig = visualize_num_bphs(result)
   output_file = joinpath(
      figdir, "param-fix-num-init-bphs.png"
   )
   save(output_file, fig; px_per_unit)
   @info "Figure written to $output_file"
   result = nothing
   GC.gc()

   # Fix energy transfer plot
   result = SimulationResult(
      "outputs/scan-energy-transfer/"
   )
   fig = R.draw_pct_bphs(result)
   output_file = joinpath(
      figdir, "param-fix-energy-transfer.png"
   )
   save(output_file, fig; px_per_unit)
   @info "Figure written to $output_file"
   result = nothing

   #  result
   plot_sobol_sa(figdir)
end

main()
