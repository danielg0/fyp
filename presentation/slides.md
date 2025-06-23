---
title: Variable length benchmark traces in microarchitecture simulation experiments
author: Daniel Gregory
data: 2025-06-23
theme: metropolis
---

- **Super-sampling** existing profiling data to eliminate time spent resimulating programs for new interval sizes.
- Showing **truncated** checkpoints have similar error rates to traditionally collected checkpoints.
- Combine checkpoints of different interval sizes with design-space exploration tools to find performant microarchicture configurations quickly.

# SimPoint Process

![](../diagrams/present_simpoint_1.1.drawio.svg)

Divide the execution of target binary into intervals

# SimPoint Process

![](../diagrams/present_simpoint_1.2.drawio.svg)

Profile intervals, counting instructions run from each basic block

# SimPoint Process

![](../diagrams/present_simpoint_2.1.drawio.svg)

Plot basic block vectors as points in a basic block space

# SimPoint Process

![](../diagrams/present_simpoint_2.2.drawio.svg)

Perform $k$-means clustering to identify program phases

# SimPoint Process

![](../diagrams/present_simpoint_2.3.drawio.svg)

Pick centre point from each cluster as that phases' SimPoint

# SimPoint Process

![](../diagrams/present_simpoint_3.drawio.svg)

<!--![](../diagrams/simpoint-overview.drawio.svg)-->

Take checkpoints at each SimPoint we can resume from on-demand

# SimPoint Process Timing

| Step | Timing (minutes) |
|---|---|
| Profiling | 85 |
| Clustering | <1 |
| Checkpointing | 91 |
| Metric Estimation | 9 |

> Time required to carry out the SimPoint process on the zip benchmark from CoreMark-PRO.

# SimPoint Super-sampling

![](../diagrams/present_supersampling.drawio.svg)

# Variance versus SimPoint interval size 

<!--
Hi

```{=latex}
\pause
```
-->

![](../experiments/3_coremarkzip/plots/present_var_by_interval_ipc_explain.svg)

# Variance versus SimPoint interval size 

![](../experiments/3_coremarkzip/plots/present_var_by_interval_ipc_onecol.svg)

# Variance versus SimPoint interval size 

![](../experiments/3_coremarkzip/plots/present_var_by_interval_ipc.svg)

# Variance of SimPoints compared to random sampling

![](../experiments/3_coremarkzip/plots/present_variance_clearer.svg)

# SimPoint Truncation

![](../diagrams/present_clustering_scaling.drawio.svg)

1. Take a regular clustering of BBVs of size $N$
2. Scale down each BBV by factor $1 \over f$, creating $f$ points
3. A cluster also scaled down by $f$ fits the scaled data

# SimPoint estimate error versus interval size

![](../experiments/3_coremarkzip/plots/present_ipc_error_by_interval.svg)

# The trade-off between SimPoint error rate and simulation time

![](../experiments/3_coremarkzip/plots/present_error_pareto.svg)

# Design-space Exploration

![](../diagrams/hypermapper_explain.drawio.svg)

\quad

> Overview of HyperMapper, a design-space exploration tool

# Optimal configurations found over time

![](../experiments/6_hypermapper_zip/plots/pareto_count.svg)

# Conclusions

* We developed a method for avoiding repeated profiling of the same binary when making BBVs for different interval sizes with no loss in accuracy
* Truncation of checkpoints can eliminate the need for reprofiling or recollecting checkpoints for an existing binary with little loss in accuracy
* Combining sets of SimPoints of different interval sizes with an existing design-space exploration tool finds optimal configurations twice as fast

# Combined design-space exploration using multiple SimPoint sets

![](../experiments/6_hypermapper_zip/plots/present_facet_pareto.svg)
