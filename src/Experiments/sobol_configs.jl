const SOBOL_ET = SobolInput(;
   num_samples = 30,
   output = "outputs/energy-transfer",
   energy_transfer = (0.025f0, 0.075f0),
   init_pr_eliminate = (0.0f0, 0.0f0),
   flower_width = (0, 0),
   init_num_bphs = (200, 200),
   nboot = 2,
)

const SOBOL_N0 = SobolInput(;
   num_samples = 30,
   output = "outputs/init-num-bphs",
   energy_transfer = (0.035f0, 0.035f0),
   init_pr_eliminate = (0, 0),
   flower_width = (0, 0),
   init_num_bphs = (100, 300),
   nboot = 2,
)

const SOBOL_FLOWER_PR = SobolInput(;
   num_samples=30,
   output="outputs/flower",
   energy_transfer=(0.035f0, 0.035f0),
   init_pr_eliminate=(0f0, 1f0),
   flower_width=(0, 21),
   init_num_bphs=(200,  200),
   order=[2],
   nboot=2
)
