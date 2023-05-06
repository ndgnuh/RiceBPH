```@setup
using RiceBPH
```

# Model description

## Purpose

## Entity, state variables and scales

## Process scheduling

The agents are scheduled by the energy. The ones with lower energy perform their action first.

Agent at each stage 

## Design Concepts

### Observation

We observes percentage of healthy rice cells `r_R` and some other metrics of BPH population, which are:

## Initialization

## Input data

## Submodels

##### Agent actions
```@docs
RiceBPH.Models.agent_action_growup!
RiceBPH.Models.agent_action_move!
RiceBPH.Models.agent_action_eat!
RiceBPH.Models.agent_action_reproduce!
RiceBPH.Models.agent_action_die!
```

##### Rice cell behaviour

```@docs
RiceBPH.Models.model_action_eliminate!
```

##### Data collection

```@docs
RiceBPH.Models.model_action_summarize!
```
