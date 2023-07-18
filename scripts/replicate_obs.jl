import RiceBPH.Experiments as E
import RiceBPH.Results as R
using JDF

function main()
   # Dummy experiment to test the code
   #= rm(E.SCAN_DUMMY.output, force=true, recursive=true) =#
   #= rm(E.SOBOL_DUMMY.output, force=true, recursive=true) =#
   #= run(E.SCAN_DUMMY) =#
   #= run(E.SOBOL_DUMMY) =#

   # Real experiment
   configs = [
      E.SOBOL_ET,
      E.SOBOL_ET_WIDE,
      E.SOBOL_N0,
      E.SOBOL_FLOWER_P0,
      E.SOBOL_FLOWER_P0_WIDE,
      E.SCAN_N0,
      E.SCAN_ET,
      E.SCAN_SF_P0,
      E.SCAN_SF_P0_WIDE,
   ]
   for config in configs
      # Load
      GC.gc()
      result = R.SimulationResult(config.output)
      @info "Computing observations for $(config.output)"

      # Fit 
      GC.gc()
      ob = R.compute_observations(result)

      output_file = joinpath(
         "observations", basename(config.output)
      )
      savejdf(output_file, ob)
      @info "Output written to $output_file"
   end
end
main()
