using Distributed

import RiceBPH.Experiments as E

function main()
   E.run(E.SOBOL_ET)
   E.run(E.SOBOL_ET_WIDE)
   E.run(E.SOBOL_N0)
   E.run(E.SOBOL_FLOWER_P0)
   E.run(E.SOBOL_FLOWER_P0_WIDE)
end
main()
