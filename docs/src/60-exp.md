# Experiments and results

We perform three sets of experiments, which serves different purposes.
The first two sets are the stable analysis of a few uncertain parameters.
The last one studies the effect of flower on the rice-BPH dynamic.

## Stable analysis (energy transfer)

The first parameter to be analyzed is the energy transfer rate ``E_T``.
With ``E_T``, we perform three experiments.
Each experiments consider ``9`` values of ``E_T`` and is replicated ``100`` times.

Experiment | Parameter | Min value | Max value
---        | ---       | ---       | ---
1          | ``E_T``   | ``0.03``  | ``0.3``
2          | ``E_T``   | ``0.01``  | ``0.1``
3          | ``E_T``   | ``0.01``  | ``0.06``

Since we want to observe the stable BPH population structure, we run the simulation in with doubled space and time resolution (``5600`` steps and ``250 \times 250`` field size).
The number of initialized BPHs is ``N_I = 200``.
No flower is planted.

After replication, we analyze the BPH population when it is most stable, which is a week before the population peaks occurs.
```math
\begin{align}
t_2 &= \operatorname{argmax}\{n_A\}, \\
t_1 &= t_2 - 24 * 7.
\end{align}
```
This is because at the begin of the simulation, the population is not stablized, and at the end of the simulation, the food (rice) runs out, the population is in a declining state.

!!! danger
    TODO: add results analysis (figures, plots)

In the first experiment, the large values of ``E_T`` lead to unrealistic scenario, in which all the BPHs die early and there is no hopperburn.
This phenomenon can be easily explained with the implicit interaction of BPH agents.
Since they consume the rice too fast, it is impossible for many of them to survive, and the other few would die due to old age.

For smaller values, we found that ``E_T`` is generally not sensitive. The standard deviation is small (even when calculated over all timesteps in all replications). Moreover, the observed data ``r_N`` ranges from ``0.7`` to ``0.8``, which matches the data observed in [Syahrawati2019](@cite).
We decided to use the value of ``E_T`` that gives the closest results to [Syahrawati2019](@cite), which is ``E_T=0.032``, for later experiments.

## Number of initialized BPHs

For the parameter ``N_I``, we considers ``9`` values that range from ``20`` to ``1000`` and replicate each for ``100`` times.
We found out that ``N_I`` does not affect observed outputs much. 
For example, the deviation of ``r_N`` is very low.
Moreover, when ``N_I`` is high, the BPH populations drops to a fixed range after a few steps.
This is because BPHs invades the field from a small region, and that region have limited resources. Since they compete for foods, only a few of them survives.

## How to reproduce

To reproduce the ``E_T`` stable analysis experiment, run
```shell
julia --project scripts/run_ofaat.jl configs/energy-transfer-01.toml outputs/energy-transfer-01
julia --project scripts/run_ofaat.jl configs/energy-transfer-02.toml outputs/energy-transfer-02
julia --project scripts/run_ofaat.jl configs/energy-transfer-03.toml outputs/energy-transfer-03
```
to obtain the data. To reproduce the plot, run
```shell
julia --project scripts/plot-ofaat.jl src/RiceBPH.jl
```

## Run own experiments
