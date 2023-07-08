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

function plot_sobol_sa()
   R.draw_scatter_phase(E.SOBOL_ET)
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
   result = SimulationResult("outputs/energy-transfer/")
   fig = visualize_pct_nymphs(result)
   output_file = joinpath(
      figdir, "param-fix-energy-transfer.png"
   )
   save(output_file, fig; px_per_unit)
   @info "Figure written to $output_file"
   result = nothing
   GC.gc()

   plot_sobol_sa()

   #  result
   #= results = ( =#
   #=    "outputs/energy-transfer/", =#
   #=    "outputs/init-num-bphs/", =#
   #=    "outputs/init-pr-eliminate/", =#
   #=    "outputs/flower-width/", =#
   #= ) =#
   #= for result_folder in results =#
   #=    @info "Processing $result_folder" =#
   #=    result = SimulationResult(result_folder) =#
   #=    df = compute_observations(result) =#
   #=    GC.gc() =#

   #=    # Stability analysis plots =#
   #=    fig = visualize_qcv(result, df) =#
   #=    output_file = joinpath( =#
   #=       figdir, "stability-$(first(result.factors)).png" =#
   #=    ) =#
   #=    save(output_file, fig; px_per_unit) =#
   #=    @info "Figure written to $output_file" =#
   #=    GC.gc() =#
   #= end =#
end

plot_sobol_sa()
