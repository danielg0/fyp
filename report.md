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

    %% Multicolumn sections
    \usepackage{multicol}

    \usepackage{pifont}

    %% make sure footnotes don't wrap to the next page
    \interfootnotelinepenalty=10000

    %% Included to make secnos work
    \usepackage{hyperref}
    \usepackage{cleveref}

    %%lmao
    \usepackage{xcolor}
    ```
link-citations: true
secnos-cleveref: true
fignos-cleveref: true
---

<!-- manually encode abstract & toc to get order right -->

```{=latex}
\pagecolor{white}
\begin{abstract}
```

Fast evaluation of new hardware ideas is crucial for effective research in processor microarchitecture. Simulations of benchmark programs are an important tool to achieve this and representative sampling techniques, such as SimPoint, accelerate this process by profiling a program to identify subsets of it that are representative of the whole execution. Previous work has shown that estimates of performance metrics gathered by simulating just those selected intervals can be very accurate if they are sufficiently long.

This thesis introduces a technique for combining short and long simulation intervals with parameter optimisation methods from the ML domain to efficiently measure the effect of hardware changes. Our main contributions include:

- Investigating the trade-off between error and simulation time present when choosing a simulation interval's size.

- Discussing interval sub-sampling and super-sampling techniques to efficiently generate new simulation intervals from existing profiling runs. These techniques result in a Y% decrease in CPU time required to pick simulation points.

- Demonstrating the viability of combining multiple simulation interval sets of different sizes with modern ML techniques for parameter optimisation to efficiently find performant configurations.

- Presenting an implementation that can find the Pareto front of a design-space exploration experiment on a benchmark program with X% less simulation time than traditional techniques.

The techniques this thesis introduces will contribute to more efficient use of simulation time in microarchitecture research with minimal opportunity cost by reusing expensive profiling and checkpointing data already collected. It empowers researchers to explore more avenues for performance gain by giving them the tools to quickly evaluate a suite of ideas before delving further into those that show promise.

Our discussions lay the path for future exploration into the variance of SimPoint sets, the computation of error bars on performance metric estimates made using SimPoints and how we can use them for prior injection into the optimisation process.

```{=latex}
\end{abstract}
```

```{=latex}
\renewcommand{\abstractname}{Acknowledgements}
\begin{abstract}
```

I would like to give many thanks to Paul, Jacky and Luke for their abundant support and advice throughout this project. I am also grateful to my family and friends for their constant encouragement, without which I would not be in the place I am today.

```{=latex}
\end{abstract}
```

```{=latex}
\tableofcontents
% \listoffigures
```

# Introduction

Modern computer architecture research often simulates how new designs would perform on existing benchmark suites like SPEC CPU 2017 [@speccpu2017] as chip fabrication is expensive. Simulation is still a lengthy process, with single runs taking weeks or months, a cost at odds with the desire to test many different configurations of hardware parameters (cache sizes and associativities, register counts, store queue lengths, etc.) to accurately identify configurations that minimise energy and maximise performance to build a Pareto front[^pareto]. As a result, much research has been done both on speeding up simulators and estimating a benchmark result from samples of a program's execution to reduce the amount of instructions that must be simulated.

[^pareto]: The Pareto front is the set of "efficient" configurations which cannot be changed to improve on one metric (power usage, instructions per cycle, etc.) without another metric worsening.

This has resulted in the development of SimPoint [@simpoint1], a tool for profiling a program and identifying the phases present in it using clustering algorithms. By extracting "SimPoints", samples representative of those phases, we can accurately estimate performance metrics whilst executing a fraction of a full benchmark. The number of instructions that need simulating and error of a given set of SimPoints is influenced by several variables, including the width of those generated samples [@tracedoctor], measured as the number of instructions executed per sample.

This thesis explores techniques for splitting and combining collected profiling data to create SimPoints of different widths and then demonstrates the tradeoff between error rate and simulation time of those resultant SimPoints. Using these techniques, we show that given a single set of profiling data or simulator checkpoints, we can construct several SimPoint sets of varying widths faster than the traditional SimPoint technique, and that they estimate performance metrics with a similar range of error rates.

Bayesian optimisation is an approach to determine the minimal value of a black-box function with few evaluations. Modern Bayesian optimisers [@hypermapper2] can work with multiple discrete or continuous parameters with constraints on their values. This makes them ideal for working with hardware parameters, where we want to limit exploration to designs that are feasible. Previous work has applied this technique to problems in the computer architecture space, such as calibrating simulator parameters to minimise error relative to a target machine [@gem5tune].

By combining our SimPoint scaling approach with Bayesian optimisation, we will demonstrate a novel approach for design space exploration that uses multiple sets of differently-sized samples to estimate performance metrics for potential hardware configurations faster than traditional random sampling. With this, we can quickly assess a wider range of the hardware configuration space whilst retaining a high level of confidence in the optimality of the final Pareto front.

We then demonstrate our implementation of this approach on a subset of the CoreMark-PRO [@coremarkpro] benchmark suite, showing that it identifies optimal hardware configurations faster than traditional techniques and is therefore a viable tool for future computer architecture investigations.

\newpage

## Contributions

This thesis:

- Introduces a method for scaling up profiling information used to generate SimPoints in order to reduce simulation time spent reprofiling programs with no loss in accuracy ({@sec:super-sampling}). In an experiment where SimPoints are generated for eight different simulation interval widths, this reduces overall execution time by X% ({@sec:results}).

- Gives mathematical reasoning that truncating the simulation of selected SimPoints after $T$ instructions is equivalent to rerunning the SimPoint process on profiling data equally split into intervals $T$ instructions wide ({@sec:sub-sampling-using-checkpoint-truncation}). Subsequently, we experimentally demonstrate that these truncated checkpoints achieve similar error rates to repeated application of the standard SimPoint approach ({@sec:results}).

- Presents a method for using a set of SimPoints of different interval lengths with an existing Bayesian Optimiser in order to find performant configurations in a design space exploration experiment using less simulation time than existing SimPoint techniques ({@sec:todo}).

- Evaluates our new design space exploration method on a CoreMark-PRO [@coremarkpro] benchmark ({@sec:todo}) demonstrating we find Pareto fronts X% faster than with a random search, concluding with a discussion on how future research could make use of the work we have done to make effective use of limited computation budgets ({@sec:todo}).

\todo{Technique Overview \& Applications}

<!--

```{=latex}
\begin{multicols}{2}
```

![](experiments/3_coremarkzip/plots/ipc_error_by_interval.svg)
\addtocounter{figure}{1}
\hypertarget{plot-a}{Figure \thefigure: A diagram giving an overview of our checkpoint collection methodology.}


```{=latex}
\columnbreak
```

![](experiments/3_coremarkzip/plots/ipc_error_by_interval.svg)
\addtocounter{figure}{1}
\hypertarget{plot-b}{Figure \thefigure: A diagram giving an overview of our checkpoint collection methodology.}

```{=latex}
\end{multicols}
```
-->

# Background

This chapter provides an overview of the prerequisite knowledge required for this thesis. We discuss the microarchitecture simulation space, with a focus on Gem5 [@gem5], and then go into greater detail on the previous research done on sampling a program's execution in order to estimate performance metrics, leading up to the development of the SimPoint [@simpoint1] technique. Finally, we introduce Bayesian optimisation and discuss one implementation, HyperMapper [@hypermapper2], and the features it offers that make it suitable for hardware design-space exploration experiments.

## Simulators

Fabricating new hardware is a long and expensive process, so simulators like gem5 [@gem5], zsim [@zsim] and SimpleScalar [@simplescalar] are used to evaluate new microarchitecture designs before they become silicon. By running benchmark suites, collections of programs that are representative of common computing workloads, performance comparisons can be made with existing designs.

These simulators are all open-source, with their code and documentation available freely online. This makes it possible for researchers to extend them with novel hardware structures and examine the effects of these extensions on overall system performance.

Both SimpleScalar and gem5 provide different CPU models that span a spectrum between:

- Fast functional simulators that emulate just the instruction set of a machine such as gem5's `AtomicCPU` and SimpleScalar's `sim-fast`, which can achieve simulation speeds of 6 MIPS[^mips] [@simplescalar, Table 1], whilst collecting information on the flow of execution.

- Slower microarchitecture simulators that can track out-of-order scheduling, data hazards, functional units, cache hierarchies, etc. to produce accurate values for IPC[^ipc] when executing a given program. These cycle-accurate models include gem5's O3 model and SimpleScalar's `sim-outorder` which simulates at speeds of 0.3 MIPS.

[^mips]: MIPS: Millions of Instructions Per Second.
[^ipc]: IPC: Instructions Per Cycle.

Where gem5 differs from zsim is in the approach taken to executing instructions. gem5 emulates instructions, decoding each one and applying its effects to the simulator's state. In contrast, zsim uses binary instrumentation, where the program is modified to add in logging around basic blocks ({@sec:basic-blocks}), memory accesses, etc. that can be used to determine the simulation's timing. The modified binary is then run natively, relying on the host processor to maintain the functional state of the simulator. Instrumentation, due to running natively, is often faster than emulation, but relies on the simulated architecture matching the hosts - gem5 in comparison is more portable and can simulate novel architectures and architecture extensions[^magic-nops] if required.

[^magic-nops]: That said, instrumenting simulators can simulate new instructions added to existing architectures using "magic NOPs", no-operation instructions of a specific form that can be detected by the simulator and won't appear in the binary otherwise [@zsim; @gems].

### DL-based Simulators

One recent development in the microarchitecture simulation space is in the use of machine learning to train models that can predict latencies [@simnet; @tao]. Deep Learning (DL) is performed on an execution trace that contains the static features of each instruction, such as target/source registers and branch type, as well as the architecture context, made up of instruction context, including flags for memory dependancy, and history context, containing information on recent branch mispredictions and data accesses. Having been trained on one program's trace and corresponding timings, the model can be used on other programs to estimate their timings (fetch, execution and store latencies).

The trained model can be run on a GPU and achieve simulation speeds faster than traditional CPU simulators - on SPEC benchmarks an overall speedup (ie. including training) of 3.66x versus Gem5 was measured by [@tao, table 4]. However, the model is specific to that particular microarchitecture configuration, so changes to its parameters require the model to be retrained. As a result, a simulator of this design is not appropriate for the use-case we envision, testing many different microarchitecture configurations on the same program.

### Abbreviated Runs

Evaluating a whole benchmark suite with a simulator's cycle-accurate model is temporally expensive, requiring weeks or months of CPU time for a single run, but simulating with a functional model will not produce as accurate performance metric values. To alleviate this, we could run our functional simulator for several hundred million instructions to skip the program initialisation, then switch to our cycle-accurate simulator and continue running for hundreds of millions of instructions, using that model to collect a final performance metric. In 2003, [@smarts-paper] observed that "more than half of [papers in the last year] in top-tier computer architecture conferences presented performance claims extrapolated from abbreviated runs", but this approach can produce misleading results, as it may not accurately represent long-term program behaviour [@abbrunsinaccurate].

Instead, modern research \todo{find examples of research} uses several different sampling methods that are based on statistical theory or on profiling the target program to learn about its behavior during execution.

## Sampled Simulation Techniques

Accurate simulations of entire benchmark suites can take days or weeks to complete. Rather than simulate them entirely, we can simulate a portion and use that to estimate overall performance. This chapter discusses three different methods for picking a sample to simulate.

Many simulators offer both accurate cycle-level models and fast functional models. In order to achieve a balance between the accuracy and speed of these two models, we can run a cycle-accurate simulator on a subset of a program's complete execution and use the functional model for the rest. There are three main approaches to sampling a program [@simpoint-textbook, Ch 6] that can produce results that are representative of a programs varying behaviour:

- Random sampling, where we distribute the sets of instructions that we sample randomly throughout the entire execution

- Periodic sampling techniques, such as SMARTS (see {@sec:smarts}), where those sets are distributed regularly throughout the execution - the distance from one set to the next is predetermined

- Representative, or targeted, sampling techniques such as SimPoint (see {@sec:simpoint}), which start by analysing the program, then pick the sets of instructions to sample that collectively represent the full behaviour of the program

{\*@fig:sampling-techniques} shows one set of samples that could be picked using these three methods for a given program. The random samples are distributed randomly throughout the program whereas the periodic occur at regular intervals. Targeted samples are taken for the three different phases in the program, which correspond to the three different IPC behaviours.

![Potential sets of samples for the different sampling techniques, based on [@simpoint-textbook, Fig 6.2]](diagrams/sim-sample-techniques.drawio.svg){#fig:sampling-techniques}

### Statistical Sampling

Both random and periodic sampling are statistical sampling techniques that build upon existing mathematical theory, such as the central limit theorem, which is explained in this section.

The central limit theorem states that if sufficient independent observations are taken of a population (in practice, more than thirty) with a finite variance $\sigma^2$ and mean $\mu$, then the distribution of the sample mean $\bar{x}$ approximates a normal distribution with mean $\mu$ and variance $\sigma^2 \over n$, irrespective of how the population is distributed.

Practically, if we use a statistical sampling method on a program and take $n$ samples of a performance metric, $[x_1, \ldots, x_n]$, we can calculate a sample mean $\bar{x}$ and sample variance $s^2$ as follows:

$$\bar{x} = {\sum_{i=1}^n x_i \over n}$$

$$s^2 = {\sum_{i=1}^n (x_i - \bar{x})^2 \over n - 1}$$

Then the distribution of $\bar{x}$ approximates a normal distribution with the true value of the performance metric for the program as its mean. We can use this to find a confidence interval for the sample mean to an amount of confidence $c$, for instance 99%:

$$\left[ \bar{x} - z_{1-c \over 2} {s \over \sqrt{n}}, \bar{x} + z_{1-c \over 2} {s \over \sqrt{n}} \right]$$

Where the value $z_{1-c \over 2}$, the $(100c)$th percentile of the standard normal distribution, is taken from a precomputed table. The probability that the true mean value of the metric $\mu$ resides within this interval is $c$.

### SMARTS

SMARTS [@smarts-paper] is a periodic sampling technique that switches at regular intervals between an accurate cycle-level simulation used to collect metrics and a fast functional simulator that quickly reaches the next sampling point.

[@smarts-paper] uses the mathematical theory in {@sec:statistical-sampling} to predetermine the size, $n$, of program samples based on a desired confidence level of the final performance metric. This also requires the calculation of a coefficient of variation $V$:

$$V = {\sigma \over \mu}$$

This typically is not known beforehand, so the SMARTS approach estimates its value using an initial large sample of size $n_\textnormal{init}$. If this initial sample's variance, $\hat{V}$, is insufficient for the target confidence level, then a new value for the size of the sample $n_\textnormal{tuned}$ can be calculated from $\hat{V}$.

Once we know how large to make the sample, the SMARTS technique involves alternating between running a cycle-accurate and functional simulator model. The final metric result is calculated based on the $n$ sample phases. We also track the measured coefficient of variance $\hat{V}$ so we can compute the confidence bounds on our estimate. The value of $\hat{V}$ can also be reused to calculate the initial sample size for future experiments on the same program.

#### Warm-up

One practical concern to handle when switching between functional and cycle-accurate simulation is warming up the processor. Modern processors contain a lot of internal state essential for achieving good performance, including branch predictors for prefetching upcoming instructions and multiple levels of caching to speed up accesses with temporal locality, that is not maintained during functional simulation. As such, if nothing is done they will be stale or "cold" upon switching to the cycle-accurate simulation, leading to an increase in cache misses and branch mispredictions that would not occur in a complete execution. Without warm-up, these misses and mispredications would increase the error in estimated performance metrics.

How best to solve this has been the subject of much research. [@samplestartcontextswitch] proposed a method where samples start being collected only after a context switch, under the assumption that at least for smaller caches, the cache will be flushed during the switch. [@reversestatereconstruction] suggests tracking the data that is needed for reconstructing architecture state during functional simulation, so that once the switch to cycle- accurate simulation is made, the processor structures can be filled back up in reverse. [@simplescalar] has an option to give each piece of architectural state a warmup bit; when switching from functional simulation, this bit is set for all structures. The first time that structure is accessed, the bit is unset and the access is assumed to be sucessful, the intuition being that most structures have high hit rates. SMARTS approaches this problem in two ways: with detailed warming and with functional warming.

Before each sample of size $n$, SMARTS has a period of detailed simulation of size $w$ that is not recorded, called detailed warming. This period fills the cache back up with fresh information so that the sample is executing in an environment as close to reality as possible. Picking a value for $w$ is tricky, as it adds a lot of cost to the overall simulation and the best value is highly dependant on the program being executed, so [@smarts-paper] also introduced the concept of functional warming, a middle point between functional simulation and detailed warming. By augmenting the functional simulator model with the ability to maintain some of the microarchitecture state, notably the branch predictor and caches, $w$ can be reduced at the cost of a "small" slowdown in-between samples[^slowdown].

The resulting sampling looks as follows:

1. $n(k - 1) - w$ instructions are executed through functional warming

2. $w$ instructions are executed through detailed warming to prepare the architecture state not maintained through functional warming

3. $n$ instructions are executed in detailed mode with the cycle-accurate simulator in order to collect the measured performance metric

[^slowdown]: The paper implemented a functional warming model that could operate at 55% the speed of the existing function simulation model.

### SimPoint

SimPoint [@simpoint1] is a representative sampling technique that tracks the code executed by a program and uses that to decide where to sample in order to include all the behaviours it exhibits. This section will introduce the technique and discuss some further research to extend its functionality.

![A summary of the original SimPoint [@simpoint1] process](diagrams/simpoint-overview.drawio.svg){#fig:simpoint-summary}

SimPoint is composed into three parts, collection of a program trace, use of that program trace to identify the different phases of behaviour in the program and selection of samples to simulation from each of those phases. The process of identifying phases is shown in {@fig:simpoint-summary} which is labelled as follows:

1. Simulate the entire program on a simplified CPU, tracking the basic blocks ({@sec:basic-blocks}) being executed in order to build basic block vectors (BBVs)

2. Represent those vectors as points in a basic block space

3. Perform a random linear map on the set of BBVs to reduce the dimensionality of the data

4. Group the BBVs using $k$-means clustering ({@sec:k-means-clustering}), which identifies the phases in the program

5. Pick a BBV, and corresponding interval, closest to the centre of each cluster to represent it as its "SimPoint", taking care to also record the proportion of BBVs in that cluster

To produce a final performance metric, we do a detailed simulation of the chosen SimPoints for each cluster, collecting performance metrics of interest. We then weight the performance metrics of each phase by the proportion of BBVs in that phase's cluster. One advantage SimPoints has over statistical sampling techniques is that as it has more information on the execution of the program, it can take less samples than SMARTS might and still produce an accurate estimate, reducing the required runtime of our simulation [@smarts-paper, Ch 5.3].

#### Basic Blocks

Introduced by [@simpoint1], SimPoint is based on the insight that many programs have repeated phases of similar behaviour. By identifying these phases and simulating samples of the program that exhibit those phases' behaviours, we can produce good estimates for metric values over the whole runtime of the program. The behaviour of a given section of a program can be characterised by the instructions it executes [@bbv-perf-correlation], and so the SimPoint approach identifies phases by considering basic blocks, sections of the program with a single entry and exit point that contain no control flow. For example, the following C function to find the maximal element of an array has 6 basic blocks, annotated 1-6 in the x86 assembly output on the right:

```{=latex}
\begin{multicols}{2}
```

```c
int maxArr(int *arr, int len) {
    if (len <= 0)
        return -1;
    
    int max = arr[0];
    for (int i = 1; i < len; i++)
        if (arr[i] > max)
            max = arr[i];
    return max;
}
```

[_Compiled with GCC 14.2 using Godbolt_](https://godbolt.org/#g:!((g:!((g:!((h:codeEditor,i:(filename:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,selection:(endColumn:20,endLineNumber:15,positionColumn:20,positionLineNumber:15,selectionStartColumn:20,selectionStartLineNumber:15,startColumn:20,startLineNumber:15),source:'%23include+%3Cstdio.h%3E%0A%0Aint+maxArr(int+*arr,+int+len)+%7B%0A++++if+(len+%3C%3D+0)%0A++++++++return+-1%3B%0A++++%0A++++int+max+%3D+arr%5B0%5D%3B%0A++++for+(int+i+%3D+1%3B+i+%3C+len%3B+i%2B%2B)%0A++++++++if+(arr%5Bi%5D+%3E+max)%0A++++++++++++max+%3D+arr%5Bi%5D%3B%0A++++return+max%3B%0A%7D%0A%0Aint+main(void)+%7B%0A++++int+a%5B4%5D+%3D+%7B-17,+34,+34,+34%7D%3B%0A++++printf(%22%25d%5Cn%22,+maxArr(a,+2))%3B%0A++++return+0%3B%0A%7D'),l:'5',n:'0',o:'C%2B%2B+source+%231',t:'0')),k:33.333333333333336,l:'4',n:'0',o:'',s:0,t:'0'),(g:!((h:compiler,i:(compiler:g142,filters:(b:'0',binary:'1',binaryObject:'1',commentOnly:'0',debugCalls:'1',demangle:'0',directives:'0',execute:'0',intel:'0',libraryCode:'0',trim:'1',verboseDemangling:'0'),flagsViewOpen:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,libs:!(),options:'-O',overrides:!(),selection:(endColumn:17,endLineNumber:9,positionColumn:17,positionLineNumber:9,selectionStartColumn:17,selectionStartLineNumber:9,startColumn:17,startLineNumber:9),source:1),l:'5',n:'0',o:'+x86-64+gcc+14.2+(Editor+%231)',t:'0')),k:33.333333333333336,l:'4',n:'0',o:'',s:0,t:'0'),(g:!((h:output,i:(compilerName:'x86-64+gcc+14.2',editorid:1,fontScale:14,fontUsePx:'0',j:1,wrap:'1'),l:'5',n:'0',o:'Output+of+x86-64+gcc+14.2+(Compiler+%231)',t:'0')),k:33.33333333333333,l:'4',n:'0',o:'',s:0,t:'0')),l:'2',n:'0',o:'',t:'0')),version:4)

```{=latex}
\columnbreak
```

```asm
maxArr(int*, int):
        test    esi, esi                ; --- BB #1
        jle     .L4                     ; __|
        mov     edx, DWORD PTR [rdi]    ; --- BB #2
        cmp     esi, 1                  ;   |
        jle     .L1                     ; __|
        lea     rax, [rdi+4]            ; --- BB #3
        lea     ecx, [rsi-2]            ;   |
        lea     rsi, [rdi+8+rcx*4]      ; __|
.L3:
        mov     ecx, DWORD PTR [rax]    ; --- BB #4
        cmp     edx, ecx                ;   |
        cmovl   edx, ecx                ;   |
        add     rax, 4                  ;   |
        cmp     rax, rsi                ;   |
        jne     .L3                     ; __|
.L1:
        mov     eax, edx                ; --- BB #5
        ret                             ; __|
.L4:
        mov     edx, -1                 ; --- BB #6
        jmp     .L1                     ; __|
```

```{=latex}
\end{multicols}
```

By tracking which basic blocks are executed in an interval we get a "fingerprint" for its behaviour. If two intervals execute the same or similar basic blocks, they executed similar instructions and so the measured value of metrics should also be similar. More formally, we build Basic Block Vectors (BBVs) at regular intervals, typically on the order of millions of instructions, during execution of the program. A BBV is a one-dimensional vector with an entry for each basic block present in the entire program, holding the number of times during the interval an instruction from that basic block was executed. The BBV stores the number of instructions executed from each basic block, rather than the number of times each basic block was executed, so that short basic blocks are not overrepresented when they are executed many times, as each run constitutes less of the overall execution than a run of a longer basic block.

We can treat all the collected BBVs as points in an $n$-dimensional space, where $n$ is the number of basic blocks in the program. Then, the Euclidean distance between two points can be used as a metric for their similarity, calculated as follows for two BBVs $(a_1, \ldots, a_n)$ and $(b_1, \ldots, b_n)$:

$$\sqrt { \sum_{i=1}^n (a_i - b_i)^2 }$$

To identify the phases of the program from the BBVs, we want to find groups of points in our space that are close together, and so have similar program behaviour. This is a clustering problem which can be solved using algorithms from the field of machine learning. The original implementation, [@simpoint1], used $k$-means clustering, which is briefly discussed below.

<!-- whereas [@simpoint-clustering] proposed using multinomial clustering instead. These are briefly discussed below.

### Clustering
-->

#### $k$-Means Clustering

$k$-Means clustering iteratively splits BBVs into $k$ sets, where $k$ is chosen before the process begins. First, a random linear map is performed on the BBV space to reduce the dimensions from the, potentially very high, number of basic blocks in the program, typically to fifteen - this avoids "the curse of dimensionality", where a high number of dimensions reduces the effectiveness of $k$-means clustering. Then, $k$ random points are picked to act as the initial centres of each set, and the following steps are followed:

1. For each BBV, measure its Euclidean distance to each centre and assign it to the centre closest to it

2. For each centre, calculate the mean average position of every BBV assigned to it and move that centre to there

These two steps are repeated until which BBVs are assigned to which clusters stops changing. The BBV closest to each cluster’s centre is the one used to represent the whole cluster. In addition to recording that, the number of BBVs in each cluster is recorded. Estimating a performance metric then consists of fast-forwarding to the start of each clusters representative BBV using a functional simulator model[^warming], recording that metric during the sampled interval, and fast-forwarding to the next cluster. Once collected, the metrics for each cluster are combined into an average weighted by the number of BBVs in each cluster. For instance, given a clustering, $C$, and an array of collected metrics, $M$, we can calculate a final estimate for the metric, $E$, as follows:

[^warming]: Whether warming up architecture state is needed with SimPoint is a point of contention - [@smarts-paper, Ch 5.3] argues that as SimPoint has larger simulation intervals than SMARTS it's unneeded, whereas the original authors gave options for using the SimPoint approach both with and without warmup [@simpoint-warming] and more recently, [@livecache] has shown that by using warmup.

$$C = \left\{c_1: [BBV_1, BBV_5, \ldots], c_2: [BBV_2, BBV_4, \ldots], \ldots, c_k: [BBV_3, BBV_9, \ldots]\right\}$$

$$M = [m_1, \ldots, m_k]$$

$$E = {\sum_{i=0}^k m_i |c_i| \over \sum_{i=0}^k |c_i|}$$

The value of $k$ picked is important - too low and the final clusters may not represent the full execution, too high and multiple similar BBVs are picked as centres, increasing simulation time without benefiting the accuracy of the final result. To pick the best value of $k$, the SimPoint approach iterates through values from one up to the maxK parameter, performing a $k$-means clustering for each. Then, a metric called the Bayesian Information Criteria (BIC) is calculated for each one, that measures how well the clustering formed fits the data present. [@simpoint1] uses a definition of BIC from [@bic] which is briefly described below.

The BIC is made up of a likelihood and a penalty. The likelihood characterises how well the data fits the model - if each cluster is modelled as a spherical Gaussian distribution, the likelihood of the entire clustering is the product of the likelihood of each cluster, which in turn is the product of the probabilities of each point to be in its clusters Gaussian distribution. More clusters reduce this probability without needing to describe the data any better, so there’s a need for a second term to compensate, a penalty that increases the more nodes there are.

These terms are as follows, where $R$ is the number of BBVs, $R_i$ is the number of BBVs in cluster $i$, $\sigma^2$ is the mean variance of the distance from each BBV to its cluster's centre, $d$ is the number of dimensions to the data, there are $k$ clusters, $p_j$ is the number of parameters and $l(D \mid k)$ the likelihood of the data being distributed as $D$ given $k$ clusters:

$$l(D \mid k) = \sum_{i=1}^k - {R_i \log 2\pi \over 2} - {R_i d \log \sigma^2 \over 2} - {R_i - 1 \over 2} + R_i \log {R_i \over R}$$

$$p_j = (k - 1) + dk + 1$$

$$\textnormal{BIC}(D, k) = l(D \mid k) - {p_j \log R \over 2}$$

Once a BIC score is generated for the all the $k$ SimPoint is considering, it determines the greatest score, $\textnormal{BIC}_\textnormal{max}$ and then multiplies it by the BIC threshold parameter. The SimPoint approach then picks the clustering with the smallest $k$ that has a BIC clustering greater than that product [@tracedoctor].

<!--
#### Multinomial Clustering

The process of $k$-means clustering is fast, however it is not guaranteed to find an optimal solution and

...
-->

#### Early Points

Picking SimPoints from the centre of the detected clusters ensures they are representative of the BBVs in that cluster, but it can also result in functionally simulating through other intervals with very similar behaviour. [@simpoint-early-and-stats] recognises this and extends the SimPoints approach to consider how far an interval is through the program when picking which one represents each cluster. The aim is to pick a representative cluster that is earliest in the program, such that simulation time, either during fast-forwarding or while taking checkpoints, is minimised.

To try and choose clusterings where there is a BBV that occurs early in every cluster, the authors created a new variable _EarlySP_, based on the BIC score, where _StartLastCluster_ is a percentage representing how far through execution the last cluster is encountered, and $w$ is a weight to influence the impact this has on the final BIC:

$$\textit{EarlySP} = \textnormal{BIC} \times \left(1 - {\textit{StartLastCluster} \over w}\right)$$

Once a value of $k$ and a BBV clustering has been decided using this new BIC, an upper bound on how far through the binary we will to simulate is determined by picking an early sample from the cluster whose centre is latest in the binary. This early sample is picked by ordering all the BBVs for that latest cluster by Euclidean distance to the centre, then picking the BBV from the top 1% that occurs earliest. Then, when picking simulation points from other clusters, we limit our choice to BBVs that occur before this upper bound, otherwise following the standard SimPoint procedure in picking the closest BBV to the centre of each cluster.

#### Limitations

As the collection of BBVs requires identifying all the basic blocks in a program, we’re limited to analysing non-self-modifying binaries. For just-in-time (JIT) compiled programs, recompilation of a function with optimisations enabled will obscure the similarity in code calling that function after from those calls before the recompilation, and reuse of code cache in long-running programs could create false similarity between unrelated intervals. This hinders the ability of the SimPoint approach to identify phases accurately.

#### Validation Studies

The effectiveness of the SimPoints approach in accurately estimating performance metrics has been shown experimentally. The original authors demonstrated its effectiveness in estimating the CPI of SPEC CPU benchmarks in [@simpoint-early-and-stats], and [@power-simpoint] verified these results and extended them to show the SimPoint approach could also be used to estimate power usage.

## Bayesian Optimisation

Bayesian optimisation is an approach to determine the minimal value of a function with few evaluations of the function. Modern Bayesian optimisers [@hypermapper2] can work with multiple discrete or continuous parameters with constraints on their values. This makes them ideal for working with hardware parameters, where we want to limit exploration to designs that are feasible. They also have the ability for a user to pass in a prior distribution, representing preexisting knowledge about the problem space and where the optimal solution may exist that can be used to drive where we evaluate the function next.

\todo{discuss gem5tune paper Jacky mentioned}

### Hypermapper

# Generating Basic Block Vectors

The first step in building multiple sets of simpoints is collecting an array of basic block vectors (BBVs) (see {@sec:simpoint}) for each simulation interval $i_1, i_2, \ldots, i_N$ of interest. The gem5 simulator [@gem5] has the ability to generate BBVs from a functional simulation of a program for a single given target interval. We could repeat this simulation for each interval we want a set of simpoints for, requiring time linear with respect to $N$. This entails inefficiently simulating an identical program multiple times - we can instead take an existing BBV array and "super-sample" it to construct a BBV of a greater interval or "sub-sample" it to produce one of a smaller interval, without additional simulation. In this chapter, we will discuss methods for sub- and super-sampling BBV arrays and their trade offs. 

As a reminder, a BBV expresses the behaviour of a single interval in a program as a vector storing the number instructions executed in that interval from each basic block in the entire program. A sequence of BBVs then represents the behaviour of an entire program where the first element represents the first interval's worth of instructions, the second the behaviour of the instructions in the second interval, and so on, forming an array of BBVs.

## Super-sampling

In order to create sets of BBV arrays with different interval sizes, we can collect one set and scale it up to produce BBV arrays of greater sizes, saving simulation time collecting BBVs.

Take $a$ and $b$, two program intervals of length $N$; let the BBVs of these program intervals, the number of instructions executed from each basic block in each interval, be $B^N_a$ and $B^N_b$. The sum of their components is the number of instructions executed from each basic block in both $a$ and $b$. In an execution flow where $a$ is followed by $b$, $ab$, this is identical to a BBV taken from the beginning of $a$ of size $2N$, $B^{2N}_ab$. This is the basis of our subsampling approach, where BBVs of neighbouring intervals are combined to form the BBV of the sum interval, as illustrated in @fig:supersample-approach.

![An example of how an initial set of BBVs of interval size 4 can be super-sampled to produce BBVs of larger interval sizes. Arrows show where several basic block vectors have been summed together. As 4 is a factor of every other size, this super-sampling is optimal.](diagrams/supersampling.drawio.svg){#fig:supersample-approach}

Our approach to generate a set of BBV arrays given a set of output intervals, $is$ is:

1. Pick the smallest interval in $is$, $i_0$ as the *input interval size*

2. Create an empty BBV array for each other interval in $is$

3. Run a simulation of the program to generate an initial set of BBVs of interval size $i_0$

4. Iterate over each BBV in the generated array, tracking for each interval in $is$ other than $i_0$ a mutable BBV and an instruction counter. For each BBV:
    a. Add this iteration's BBV to each mutable BBV and add $i_0$ to each instruction counter
    b. For each interval whose instruction counter equals its interval size, append its mutable BBV to its BBV array and reset that intervals counter and mutable BBV

In the optimal configuration, where the input interval size is a factor of every output interval size, we produce BBVs identical to those that would have been produced if we had done separate simulations for each interval[^gem5_asterisk]. We also require less simulation time with our approach, using a constant amount of compute with respect to the number of target intervals.

For non-optimal configurations of intervals we add to $is$ the greatest common factor of each interval in $is$ and carry out the steps above. We posit this does not add much simulation cost to the overall generation as the interval size does not have a large impact on overall simulation time. To test this hypothesis, we took the `zip` benchmark from the CoreMark-PRO suite [@coremarkpro] and collected BBV arrays for several interval sizes using Gem5 [@gem5], measuring the user CPU time spent gathering each one (for further details on our methodology and test machine see {@sec:methodology}).

The results plotted in {@fig:cputime-vs-interval-plot} show there is not a large cost to decreasing the width of collected BBVs. A reduction in interval size from 4 million instructions to 0.5 million, creating eight times the number of BBVs, increased simulation time by 8.56% (3sf.), a rise of less than ten minutes.

![A plot of the CPU time taken to simulate and output a BBV array for the `zip` benchmark from [@coremarkpro] using Gem5 [@gem5] for a range of BBV widths.](experiments/4_simcostofintervalwidth/plots/cpu_user_time_vs_interval_width.svg){#fig:cputime-vs-interval-plot}

The super-sampling process we have described here creates BBV arrays of a variety of interval sizes from a single profiling with no loss in accuracy compared to the standard SimPoint approach. This saves computation time profiling the same binary multiple times.

[^gem5_asterisk]: In our experimentation, we noticed that when profiling with Gem5 [@gem5], the number of instructions covered (ie. the sum of all the components) by the BBVs it output would exceed or fall short of the target interval size by a couple of instructions. This is unlikely to affect the accuracy of the SimPoint process, but does cause upscaled BBV arrays to not exactly match those generated directly.

<!--
## Sub-sampling

Collecting an array of BBVs for a fresh interval size requires simulating the entire program. Even though this can be done with a functional simulator, it still takes a significant amount of time for large programs. Our super-sampling approach requires we collect an array of BBVs for the smallest sized interval we want to simulate with. We now introduce a method for producing sets of BBVs of an interval width greater than the target interval size. This enables the creation of a set of BBV arrays from a preexisting large BBV array, such as the commonly used one million wide interval size used in existing SimPoint research [@simpoint1; @power-simpoint].

Let a BBV of width $2N$, $B^{2N}_{ab} = \{3, 0, 6, \ldots\}$, contain the number of instructions executed from two continuous intervals $a$ and $b$ of length $N$. We have no way to determine the exact split of instructions between the two intervals, but we can estimate it by dividing the instructions equally between $a$ and $b$. This creates two new smaller BBVs of width $N$. The SimPoint implementation available publicly only accepts BBVs made up of integers, \todo{check this} so we round one down and one up forming split BBVs as follows:

$$B^N_a = \left\lceil {B^{2N}_{ab} \over 2} \right\rceil \qquad B^N_b = \left\lfloor {B^{2N}_{ab} \over 2} \right\rfloor$$
-->

## Sub-Sampling using Checkpoint Truncation

Collecting an array of BBVs for a fresh interval size requires simulating the entire program. Even though this can be done with a functional simulator, it still takes a significant amount of time for large programs. Our super-sampling approach requires we collect an array of BBVs for the smallest sized interval we want to simulate with. We now introduce a method for doing SimPoint analysis with an existing set of SimPoint checkpoints built on a large interval size, such as the several million instruction wide interval sizes commonly used in existing SimPoint research [@simpoint1; @power-simpoint; @dagguise].

Take a BBV of width $N$, $B^{N}_{ab} = \{3, 0, 6, \ldots\}$, containing the number of instructions executed from two continuous intervals $a$ and $b$ of length $N \over 2$. We have no way to determine the exact split of instructions between the two intervals, but we can estimate it by dividing the instructions executed from each basic block equally between $a$ and $b$. This creates two new smaller BBVs of width $N \over 2$, $B^{N \over 2}_a$ and $B^{N \over 2}_b$, both equal to $\{1.5, 0, 3, \ldots\}$. This approach generalises to any scaling factor $f$, where $0 < f < N$ - we can create $f$ smaller BBVs of width $N \over f$ by dividing each component of $B^{N}$ by $f$.

Dividing BBVs equally this way has a similar proportional effect on the $k$-means clustering of the BBVs. Recall from {@sec:k-means-clustering} that the $k$-means clustering algorithm is repeated until there is no change in cluster membership after calculating the centre of each cluster - the mean average position of each BBV in the cluster - and assigning each BBV to its closest centre. We label these terminating clusters stable - stable clusters are those where every vector is a member of the cluster closest to it and each cluster has its centre equal to the average position of every vector assigned to it. We will now show that given a stable clustering, scaling the points in that clustering forms a scaled clustering that is stable. We will then show that the closest point to each cluster's centre, the one selected as that cluster's SimPoint, remains the same after scaling.

![An illustration of how scaling every BBV by a constant factor does not affect the stability of a $k$-means clustering of the space. Crosses represent the initial BBVs, the pluses represent the overlapping scaled BBVs and the green circle is the cluster found through $k$-means clustering. The BBV in red is the one slected as the SimPoint for that cluster.](./diagrams/clustering_scaling.drawio.svg){#fig:clustering_scaling}

> Take an arbitrary $k$-means clustering of vectors $\mathbb{C}$ and assume that it is stable, as in {@fig:clustering_scaling}\medspace\ding{172}. Each cluster $C \in \mathbb{C}$ has a non-empty multiset of member vectors ${C = \{v_1, v_2, \ldots, v_{|C|}\}}$ each of cardinality $B$, the number of basic blocks in the program, and each cluster $C$ also has a centre $c = [c_1, c_2, \ldots, c_B]$, given by:
> $$c = {v_1 + v_2 + \ldots + v_{|C|} \over {|C|} }$$
> Let the closest vector in $C$ to the centre $c = [c_1, c_2, \ldots, c_B]$ be $v^\star = [i^\star_1, i^\star_2, \ldots, i^\star_B]$. There is no point $v \in C \setminus \{v^\star\}$ with components $v = [i_1, i_2, \ldots, i_B]$, such that:
> $$\begin{aligned} |v - c| &< |v^\star - c| \quad \textnormal{(\ding{61})} \\
\sqrt{(i^{\empty}_1 - c_1)^2 + (i_2 - c_2)^2 + \ldots + (i_B - c_B)^2} &< \sqrt{(i^\star_1 - c_1)^2 + (i^\star_2 - c_2)^2 + \ldots + (i^\star_B - c_B)^2} \end{aligned}$$
> As the clustering is stable, each point is assigned to its closest centre. That is to say, for some point $v$ in a cluster $C \in \mathbb{C}$ with centre $c$, there is no other cluster $C' \in \mathbb{C} \setminus \{C\}$ with centre $c'$ such that:
> $$|v - c'| < |v - c| \quad \textnormal{(\ding{81})}$$
> Then, for arbitrary factor $f > 0$, scale every vector by $1 \over f$ to produce $f$ new vectors, like {@fig:clustering_scaling}\medspace\ding{173}, where each plus represents $f$ overlapping basic block vectors:
> $$\begin{aligned} w_{1.1}, w_{1.2}, \ldots, w_{1.f} &= {v_1 \over f} = \left[{i_0 \over f}, {i_1 \over f}, \ldots, {i_B \over f}\right] \\
w_{2.1}, w_{2.2}, \ldots, w_{2.f} &= {v_2 \over f} \\
&\ldots \end{aligned}$$
>
> Create a new set of clusters $D \in \mathbb{D}$, assigning each new vector to the same multiset cluster its original vector was a part of:
> $$v_1 \in C_i \quad \Rightarrow \quad \{w_{1.1}, w_{1.2}, \ldots, w_{1.f}\} \subseteq D_i$$
> Therefore, the size of each new cluster $|D_i| = f|C_i|$. We can calculate the centre of each new cluster $D \in \mathbb{D}$, $d$, and express it in terms of the centre of its original, $c$, as follows:
>
> $$\begin{aligned} d &= {w_{1.1} + \ldots + w_{1.f} + w_{2.1} + \ldots + w_{2.f} + \ldots + w_{{|C|}.f} \over |D_i|} \\
& \textnormal{Substitute each scaled term }w_{m.n}\textnormal{ for }{v_m \over f}: \\
\Rightarrow \quad d &= {\overbrace{{v_1 \over f} + \ldots + {v_1 \over f}}^{f\textnormal{ terms}} + \overbrace{{v_2 \over f} + \ldots + {v_2 \over f}}^{f\textnormal{ terms}} + \ldots + \overbrace{{v_{|C|} \over f} + \ldots + {v_{|C|} \over f}}^{f\textnormal{ terms}} \over f|C_i|} \\
\Rightarrow \quad d &= {v_1 + v_2 + \ldots + v_{|C|} \over f|C_i|} = {1 \over f}{v_1 + v_2 + \ldots + v_{|C|} \over |C_i|} = {c \over f}\\
\end{aligned}$$
>
> Let $w^\star \in D$ be one member of the group of vectors scaled down from $v^\star \in C$, they are all equal, so $w^\star = {v^\star \over f} = [j^\star_1, j^\star_2, \ldots, j^\star_B]$. We will now show by contradiction that $w^\star$ is the vector that is closest to its assigned cluster's centre, $d$.
>
> $$\begin{aligned} \textnormal{Assume a vector }w \in C \setminus &\{w^\star\} \textnormal{ is closer to }d\textnormal{ than }w^\star\textnormal{:} \\
|w - d| &< |w^\star - d| \\
\Rightarrow \quad \left|w - {c \over f}\right| &< \left|w^\star - {c \over f}\right| \\
\Rightarrow \quad \sqrt{\left(j_1 - {c_1 \over f}\right)^2 + \ldots + \left(j_B - {c_B \over f}\right)^2} &< \sqrt{\left(j^\star_1 - {c_1 \over f}\right)^2 + \ldots + \left(j^\star_B - {c_B \over f}\right)^2} \\
\textnormal{Substitute } j_i \textnormal{ and } j^\star_i \textnormal{ for } &\textnormal{corresponding scaled-up } {i_i \over f} \textnormal { and } {i^\star_i \over f}\textnormal{:} \\
\Rightarrow \quad \sqrt{\left({i_1 \over f} - {c_1 \over f}\right)^2 + \ldots + \left({i_B \over f} - {c_B \over f}\right)^2} &< \sqrt{\left({i^\star_1 \over f} - {c_1 \over f}\right)^2 + \ldots + \left({i^\star_B \over f} - {c_B \over f}\right)^2} \\
\Rightarrow \quad \sqrt{1\over f^2}\sqrt{(i_1 - c_1)^2 + \ldots + (i_B - c_B)^2} &< \sqrt{1 \over f^2}\sqrt{(i^\star_1 - c_1)^2 + \ldots + (i^\star_B - c_B)^2} \\
\Rightarrow \quad \sqrt{(i_1 - c_1)^2 + \ldots + (i_B - c_B)^2} &< \sqrt{(i^\star_1 - c_1)^2 + \ldots + (i^\star_B - c_B)^2} \\
\Rightarrow \quad |v - c| &< |v^\star - c| \end{aligned}$$
>
> This contradicts with $v^\star$ being the closest vector to its cluster's centre $c$\medspace(\ding{61}), so we reject our assumption that there exists a $w$ closer to $d$ than $w^\star$ and instead take that $w^\star$ is the closest vector to $d$.
>
> Similarly, we can show that the clustering is stable with a proof by contradiction. Assume that one of the new scaled vectors assigned to $D$ is closer to a new cluster $D' \in \mathbb{D} \setminus \{D\}$ than $D$. Use this to show that the corresponding original vector would also be closter to $C$ than $C'$. This contradicts with the original clustering $\mathbb{C}$ being stable\medspace(\ding{81}), so the new clustering $\mathbb{D}$ must also be stable.
>
> Combining these properties, we have shown that $\mathbb{D}$ is a stable clustering of the vectors in $\mathbb{C}$ scaled by factor $f$, where the closest vectors to each cluster's centre - the SimPoint picked to represent that cluster - in $\mathbb{D}$ are those scaled from the vector closest to the corresponding cluster in $\mathbb{C}$. This is visualised in {@fig:clustering_scaling}\medspace\ding{174}.

Therefore, applying a scaling factor $f$ to each node and sampling the new closest BBV to each scaled cluster centre is equivalent to sampling a $1 \over f$ instruction long subset of the SimPoint picked by running $k$-means clustering on the original unscaled BBV array. The subset picked is arbitrary, so we pick the initial $1 \over f$ instructions at the beginning of the interval. This enables us to reuse the checkpoints gathered originally for the unscaled BBVs.

Checkpoints gathered using Gem5 [@gem5] are saved to a folder whose name follows the pattern `cpt.simpoint_XX_inst_XX_weight_XX_interval_XX_warmup_XX`, where the `XX` after each configuration variable holds the value of that attribute for that checkpoint. By creating a copy or making a symbolic link to a collected checkpoint with a large width (eg. `...interval_1000000_...`) and renaming that folder to a smaller width (eg. `...interval_250000_...`), Gem5 will stop simulating that checkpoint earlier.

Reusing checkpoints this way saves considerable time simulating an entire program in order to gather checkpoints, making evaluation of configurations with a range of intervals more viable.

This approach has the downside of potentially obscuring periodic behaviour that occurs over time-spans within the original interval size but wider than the sub-sampled interval size. Periodic behaviour that occurs over time-spans greater than the original is identified through the clustering process of the original SimPoint process, during which checkpoints are created for the different phases. However, for periodic behaviour occurring entirely within an interval size's worth of instructions, a subset of the beginning of that interval may not encounter all phases of the behaviour, leading to greater metric approximation errors.

# The Behaviour of SimPoint sets

In {@sec:generating-basic-block-vectors} we introduced two techniques for efficiently creating sets of SimPoints of different interval sizes. One takes a set of basic block vectors collected for a small interval size and scales it up to larger sizes that are a factor of the initial interval, saving profiling time. The second takes checkpoints collected for a large interval size and truncates the time they are run for in order to estimate the SimPoints that would be picked for a smaller intervals. This chapter explores the behaviour and error rate of a set of SimPoints collected using these methods on benchmarks from the CoreMark-PRO [@coremarkpro] and SPECCPU2017 [@speccpu2017] suites.

## Methodology

These results are collected on a MinisForum UM890 Pro with the following specification:

|  |  |
|--|--|
| CPU: | AMD Ryzen 9 8945HS |
| RAM: | 65 Gigabytes |
| Storage: | 2 Terabyte Seagate FireCuda 520 NVMe SSD |
| OS: | Fedora Version 42 |

x86 benchmark binaries are built with GCC 15.1.1 (installed through `dnf` package manager), ARM benchmark binaries are built with GCC 15.1.0, cross-compiled using crosstool-NG v1.27.

### Warm-up Periods

There are several views in the literature on the need for warmup when using SimPoint checkpoints and what an appropriate amount is [@smarts-paper; @simpoint-warming; @livecache; @cool-sim]. Evaluating which of these approaches is best is outside of the scope of this project, so in each of our experiments there is a single fixed warm-up value, and all checkpoints are taken with that amount of warm-up, except for those checkpoints taken from the beginning of a program where there is no preceding execution to use as warm-up. For those, we simulate the program from the beginning and set Gem5's `--maxinsts` argument to the intended interval width. Selecting a SimPoint at the beginning of a program occurs fairly commonly across our experiments, likely due to how initialisation exhibits different behaviours (system calls to open files, parsing command-line arguments, etc.) from the rest of a program's execution, though it is typically given a low weighting due to the small proportion of execution it characterises.

### Benchmark Selection

In order to calculate the error of the IPC estimates our techniques produce, we will need to perform a full cycle-accurate simulation of the benchmark programs we test. Given the limited time available to complete this project, we have therefore chosen to evaluate our approach using one of the shorter benchmarks from the SPEC CPU 2017 benchmark suite [@speccpu2017], `x264`. We are executing `x264` on its test workload to further reduce execution time - this means we cannot compare our metrics to previous reseach, but does not affect the validity of our claims significantly as we are measuring our ability to identify performant configurations of a program, not to optimise the program to enable more performant configurations. To supplement `x264`, we have also chosen a benchmark from the CoreMark-PRO suite [@coremarkpro], `zip`. The CoreMark-PRO suite is considerably smaller than SPEC CPU, so we have chosen this benchmark as it is the largest in the suite - each other benchmark in CoreMark-PRO is too short to be profiled meaningfully. \todo{give numbers on this}.

### Random Checkpoints

\newpage

### Checkpoint Collection

```{=latex}
\begin{multicols}{2}
```

Figure \hyperlink{methodology-diagram}{4.1} illustrates the complete process we have carried out to gather SimPoints and evaluate our new scaling techniques. The stages of this process are labelled as follows:

1. We take our benchmark binary and profile it using a functional model from Gem5 [@gem5], gathering an array of basic block vectors (@sec:basic-blocks) of length $N$, that record the number of instructions executed from each basic block in the program for each $N$-instruction long interval in the execution stream. $N$ is picked so that it is a factor of every interval we want to collect checkpoints for.

<!-- 2. We have written a Python script that reads through the Gem5 output, parsing each BBV and adding it to a set of vector accumulators (one for each target interval size we want to make BBVs for). When an vector accumulators size reaches its target, its written to an output file for that interval size, and the accumulator is reset. -->

2. We have written a Python script that performs a single pass through Gem5's output, parsing each BBV and summing adjacent BBVs to form BBVs arrays for each other interval size we're interested in.

3. Having generated BBVs for each interval size of interest, we perform standard SimPoint analysis on them to generate a set of clusters, their weightings and which interval we have picked as the SimPoint for each cluster.

4. With the SimPoints selected, we rerun the functional Gem5 simulator. It pauses before each SimPoint[^warmup] and takes checkpoints, snapshots of the memory and system registers we can use to resume from the same point later.

[^warmup]: Technically speaking, for a SimPoint that starts at instruction $I$, we take a checkpoint at instruction $I - W$, where $W$ is the length of our warmup period.

5. Executing collected checkpoints is done one of two ways depending on whether we're testing standard SimPoints or sub-sampled (or truncated) SimPoints:

   a. For standard SimPoints, we parse the output of the SimPoint analysis to determine which checkpoints we need to run and how to weight them in order to produce a metric estimate for each interval size.

   b. When sub-sampling, we isolate the checkpoints for a single interval, then copy and reconfigure[^truncation] them to run for each other target interval length.

[^truncation]: Gem5 encodes checkpoint parameters in the name of the folder holding the memory dump and system register state file. By creating a symbolic link to the checkpoint folder named differently, we can trivially run it for any configuration in parallel.

6. In addition to executing the checkpoints, we also run the entire benchmark program using Gem5's more accurate `O3CPU` model to produce a baseline we can calculate error values against.

```{=latex}
\columnbreak
```

<!-- manually label and increment figure counter as image too big for it to appear normally? -->
![](./diagrams/Methodology.drawio.svg)
\addtocounter{figure}{1}
\hypertarget{methodology-diagram}{Figure \thefigure: A diagram giving an overview of our checkpoint collection methodology.}

```{=latex}
\end{multicols}
```

## Results

![A plot showing how variance of SimPoint clusters decreases with interval size.](./experiments/3_coremarkzip/plots/variance_by_interval_ipc.svg)

![A plot showing how variance of a set of super-sampled SimPoints increases as interval width increases, but is still dwarfed by the variance of a set of random samples collected from across the benchmark program. This demonstrates shorter interval SimPoints with higher errors can still be useful in design space exploration as their error is consistant, and can be accounted for in the optimisation process.](./experiments/3_coremarkzip/plots/variance_clearer.svg)

![A plot of estimated IPC error versus simulated interval width. The dotted vertical line marks the interval width whose SimPoint checkpoints are used for truncation. It shows how truncated benchmarks produce similar error rates to traditional SimPoints that take longer to gather.](./experiments/3_coremarkzip/plots/ipc_error_by_interval.svg)

![A diagram showing the trade-off between simulation time and accuracy for different metric estimation methods. A Pareto front is constructed for each method that highlights how no set of SimPoints collected through either super-sampling or checkpoint truncation could be improved by being replaced with a random sampling metric. This figure further reinforces the viability of truncating checkpoints given there is no clear error or simulation time advantage to using super-sampled/traditional SimPoint collection instead.](./experiments/3_coremarkzip/plots/error_pareto.svg)

# Design-space Exploration with Short SimPoints

We perform experiments with the following scenario:

```json
{
	"application_name": "simpoint",
	"optimization_objectives": ["performance", "energy"],

	"design_of_experiment": {
		"doe_type": "random sampling",
		"number_of_samples": 10
	},
	"optimization_iterations": 49,
	"evaluations_per_optimization_iteration": 10,

	"models": {
		"model": "random_forest"
	},

	"input_parameters": {
		"rob_size": {
			"parameter_type": "ordinal",
			"values": [16, 32, 64, 128, 256, 512]
		},
		"lq_size": {
			"parameter_type": "ordinal",
			"values": [4, 16, 64, 128, 256]
		},
		"sq_size": {
			"parameter_type": "ordinal",
			"values": [4, 16, 64, 128, 256]
		},
		"p_width": {
			"parameter_type": "integer",
			"values": [4, 12]
		},
		"interval": {
			"parameter_type": "ordinal",
			"values": [125000]
		}
	}
}
```

# Future Work

- Incorporating BBV generation into Gem5

- Could Gem5 output stats periodically rather than just at the end (combine collecting IPC, etc. for the same checkpoint at different intervals).

<!--
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
        - In the event this doesn't work, or is too slow, build a heuristic
4. Investigate simpoint splitting techniques **(6th March)**
    - Build on variance result, collect variances for multiple sets in a single run
    - Look into combining intervals (ie. same cluster for n and 2n, reuse checkpoint)
5. I'm blocking off **(7th-28st March)** for exams & exams prep + 1 week holiday
6. On return during summer term, finish anything unfinished from spring term,
    - Combine above work into a usable tool
        - Python
    - Investigate questions posed as a result of 1-5
    - Gather more data on a wider range of benchmarks, see Chapter X
    - Graphs, wonderful graphs
7. Have first draft of final report done by **(11th April)**
8. Have final report finished by **(23rd May)**, leaving time for Paul/Jacky to go over it and some wiggle room for things to be delayed.


# Evaluation Plan

# Ethical Issues

If we go down the route of assessing the usability of the final tool through questionnaires of potential users, considerations will have to be made for anonymisation of recipients, the secure storage of replies and fulfillment of our requirements under GDPR.

No other ethical issues exist.

# Images

-->

<!-- ![Test plot](./experiments/1_Variance/Rplots.tex) -->

# Bibliography {.unnumbered}

::: {#refs}
:::

# Declarations {.unnumbered}

## Use of Generative AI {.unnumbered}

We acknowledge the use of popular search engines, Google ([https://www.google.com](https://www.google.com)) and DuckDuckGo ([https://duckduckgo.com](https://duckduckgo.com)), in order to find resources and debug implementation issues. Both these search engines provide generative AI-powered summaries of the top results. We confirm that no AI generated content has been presented in this thesis as our own work.

## Ethical Considerations {.unnumbered}

We believe there are no significant ethical considerations to be made regarding this thesis that are not discussed in other sections.

## Sustainability {.unnumbered}

This research has required substantial amounts of computation to profile benchmark binaries, take checkpoints for our various methods and carry out simulations to compute performance metric estimates. To give one example, a complete run of the SPEC `x264` binary to calculate baseline metric values to compare our estimates against required over 24 hours of CPU time on our test machine. We have made attempts to reduce this through reuse of data, for instance by reusing checkpoints we collected to evaluate sub-sampling ({@sec:results}) when carrying out design-space exploration experiments with HyperMapper ({@sec:design-space-exploration-with-short-simpoints}).

The environmental cost of this research is justified by the decrease in simulation time we have demonstrated in our new techniques, which will reduce the environment impact of future research that utilises it.

## Availability of Data and Materials {.unnumbered}

The Makefiles and scripts used to generate our results are available publicly on GitHub ([https://github.com/danielg0/fyp](https://github.com/danielg0/fyp)), where you can also find the R code used to produce the plots we have presented in this thesis and the Pandoc-flavoured Markdown used to write this report.

Results in this thesis are collected using [Gem5 stable v24.1.0.3](https://github.com/gem5/gem5/releases/tag/v24.1.0.3), with a change to fix a bug where resuming from a SimPoint checkpoint in a folder containing more than one hundred checkpoints picks incorrectly. We have shared our patch on GitHub ([https://github.com/danielg0/gem5](https://github.com/danielg0/gem5)).

We have tested our system on benchmarks from the CoreMark-PRO and SPEC CPU 2017 suites. CoreMark-PRO benchmarks are available publicly on GitHub ([https://github.com/eembc/coremark-pro](https://github.com/eembc/coremark-pro)) and we tested using commit `4832cc6`. We used SPEC CPU 2017 version 1.1.9 to collect results for the SPEC CPU benchmarks we tested.
