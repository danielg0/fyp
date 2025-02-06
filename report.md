---
documentclass: report
classoption:
  - a4paper
  - twoside
geometry:
  - a4paper
  - top=3cm
  - bottom=2cm
  - left=3cm
  - right=3cm
  - marginparwidth=1.75cm
hyperrefoptions:
  - colorlinks=true
  - allcolors=blue
fontenc: T1
lang: english
header-includes:
  - |
    ```{=latex}
    %% Useful packages
    \usepackage{amsmath}
    \usepackage{graphicx}
    \usepackage[colorinlistoftodos]{todonotes}
    ```
link-citations: true
---

# Introduction

Modern computer architecture research often simulates how new designs would perform on existing benchmark suites like SPEC CPU 2017 [@speccpu2017]. This is a lengthy process, with single runs taking weeks or months, a cost at odds with the desire to test many different configurations of hardware parameters (cache sizes and associativities, register counts, store queue lengths, etc.) to accurately identify the Pareto front[^pareto]. As a result, much research has been done both on speeding up simulators and reducing the amount of instructions that must be simulated to get an accurate benchmark result.

[^pareto]: The Pareto front is the set of “efficient” configurations which cannot be changed to improve on one metric (power usage, instructions per cycle, etc.) without another metric worsening.

This has resulted in the development of SimPoint [@simpoint1], a tool for identifying the phases of execution present in a program using clustering algorithms and extracting samples representative of those phases, allowing for accurate estimation of metrics whilst executing a fraction of a full benchmark. The number of instructions that need simulating and error of a given set of SimPoints is influenced by several variables, including the size of those generated samples [@tracedoctor].

We (aim to) explore multiple techniques for splitting and combining collected SimPoint samples, and measure the effect these techniques have on the error rate of the resultant samples. Using this, we (hope to) show that from a single set of collected BBVs[^bbvs], we can construct several sets of SimPoint samples with a range of error rates and simulation times. By extending the existing probability model for the SimPoint clustering approach, we aim to derive methods for determining these error rates efficiently whilst generating checkpoints.

[^bbvs]: Basic Block Vectors, for more see Section X.Y

Bayesian optimisation is an approach to determine the minimal value of a function with few evaluations of the function. Modern Bayesian optimisers [@hypermapper2] can work with multiple discrete or continuous parameters with constraints on their values. This makes them ideal for working with hardware parameters, where we want to limit exploration to designs that are feasible. They also have the ability for a user to pass in a prior distribution, representing preexisting knowledge about the problem space and where the optimal solution may exist that can be used to drive where we evaluate the function next.

By combining the SimPoint approach with Bayesian optimisation, we (aim to) construct a novel approach for design space exploration that uses multiple sets of differently-sized samples to estimate performance metrics for potential hardware configurations with confidence levels derived from our clustering probability model. By feeding this back into the Bayesian optimisation process, we can quickly assess the performance across the hardware configuration space whilst retaining a high level of confidence in the optimality of the final Pareto front.

We (will) then demonstrate our implementation of this approach on a set of benchmarks, showing that it identifies optimal hardware configurations faster than traditional techniques and is therefore a useful tool for future computer architecture investigations.

# Background

## Simulators

Fabricating new hardware is a long and expensive process, so simulators like gem5 [@gem5] and SimpleScalar [@simplescalar] are used to evaluate new microarchitecture designs. By running benchmark suites, collections of programs that are representative of common computing workloads, performance comparisons can be made with existing designs.

These simulators are both open-source, with their code and documentation available freely online. This makes it possible for researchers to extend them with novel hardware structures and examine their effect on overall system performance.

Both SimpleScalar and gem5 provide different CPU models that span a spectrum between:

- Fast functional simulators that emulate just the instruction set of a machine such as gem5’s `AtomicCPU` and SimpleScalar’s `sim-fast`, which can achieve simulation speeds of 6 MIPS[^mips] [@simplescalar, Table 1], whilst collecting information on the flow of execution.
- Slower microarchitecture simulators that can track out-of-order scheduling, data hazards, functional units, cache hierarchies, etc. to produce accurate values for IPC[^ipc] when executing a given program. These cycle-accurate models include gem5’s O3 model and SimpleScalar’s `sim-outorder` which simulates at speeds of 0.3 MIPS.

[^mips]: MIPS: Millions of Instructions Per Second
[^ipc]: IPC: Instructions Per Cycle

# Project Plan

1. Improved background **(31st Jan)**
    - Get on repo, topics covered in more depth, diagrams improved
    - Verify intuition on Simpoint limitations
2. Minimal viable project **(14th Feb)**
    - Hypermapper v2.0 being fed a prior from one smaller set of SimPoint samples and evaluating a function on a larger set of SimPoint samples
    - Good chance to compare initial sampling methods (random, hypercube, etc.)
    - Get R/tidyverse flow working in repo
3. Move to Hypermapper v3.0, using multiple layers of priors **(28th Feb)**
    - Sets of intervals of size n, 2n, 4n, . . .
    - Variance calculated using result from [@earlyVarianceSimpoints]
        - In the event this doesn’t work, or is too slow, build a heuristic
4. Investigate simpoint splitting techniques **(6th March)**
    - Build on variance result, collect variances for multiple sets in a single run
    - Look into combining intervals (ie. same cluster for n and 2n, reuse checkpoint)
5. I’m blocking off **(7th-28st March)** for exams & exams prep + 1 week holiday
6. On return during summer term, finish anything unfinished from spring term,
    - Combine above work into a usable tool
        - Python
    - Investigate questions posed as a result of 1-5
    - Gather more data on a wider range of benchmarks, see Chapter 4
    - Graphs, wonderful graphs
7. Have first draft of final report done by **(11th April)**
8. Have final report finished by **(23rd May)**, leaving time for Paul/Jacky to go over it and some wiggle room for things to be delayed.

# Evaluation Plan

# Ethical Issues

If we go down the route of assessing the usability of the final tool through questionnaires of potential users, considerations will have to be made for anonymisation of recipients, the secure storage of replies and fulfillment of our requirements under GDPR.

No other ethical issues exist.

# Bibliography {.unnumbered}

::: {#refs}
:::
