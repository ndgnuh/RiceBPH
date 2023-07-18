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
      # Fit 
      GC.gc()
      @info "Computing observations for $(config.output)"
      R.cached_compute_observations!(config)

      output_file = R.get_observation_path(config)
      @info "Output written to $output_file"
   end
end
main()
