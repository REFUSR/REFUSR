---
title: Supporting Multiple Return Values in Cockatrice
author: me
date: 2022-01-10
tags:
- draft
- cockatrice
- genetic_programming
- reverse_engineering
- boolean_functions
abstract: "Our GP engine, Cockatrice, currently only supports functions of type $\mathbb{B}^n \rightarrow \mathbb{B}^n$. Many real-world cases to which we might apply our methods, however, are of type $\mathbb{B}^n \rightarrow \mathbb{B}^m$, including an interesting case study submitted to us by William D. Jones. "
---

William D. Jones sent us a I/O table, in CSV format, for a chip he's been reverse engineering, [the ATD Model M117 memory expansion ISA card](https://github.com/cr1901/ATD_M117). 

![The ATD M117](../img/ATD_M117.png)

Regarding the table, he notes,
> The last 7 columns are outputs. The first 11 columns are inputs.

This is not *currently* a function type that REFUSR can tackle -- it's currently only able to handle functions of type $\mathbb{B}^n \rightarrow \mathbb{B}^1$  -- but it shouldn't be exceedingly difficult to add support for $\mathbb{B}^n \rightarrow \mathbb{B}^m$ functions.

Indeed, we could, in principle, *already* handle $\mathbb{B}^n \rightarrow \mathbb{B}^m$  by just treating these as a set of $\mathbb{B}^n \rightarrow \mathbb{B}^1$ functions for each individual output bit $1 \leq i \leq m$. But I'm curious where we could get if we treated all $m$ output bits at once. 

Here's what would need to be done to support that:

1. have the **virtual machine** defined in [LinearGenotype.jl](https://github.com/REFUSR/REFUSR/blob/master/GP/Refusr.jl/src/LinearGenotype.jl) use multiple return registers (defined in the `config.toml`), and refactor things so that a single return value is represented as `[n]` rather than `n` (and so on for the vectorized case).
2. adjust the calculation of the **interaction matrix** in [FF.jl](https://github.com/REFUSR/REFUSR/blob/master/GP/Refusr.jl/src/FF.jl) accordingly.
3. consider applying some of the fitness metrics to *each output individually*, or of **ranking fitness on a Pareto front** -- this is a tried and true method, and it would make a lot of sense to treat multiple-output regression as a *multi-objective optimization problem*.
4. a potential benefit of increasing the number of output registers is that could allow us to **smooth various fitness gradients** -- instead of a candidate program's response to each case being simply either *correct* or *incorrect*, there would now be room for various forms of *partial correctness* -- the state of getting $\frac{k}{m}$ outputs right, for example, or of the *incorrect* outputs nevertheless representing a *permutation* of correct outputs; experiment with these ideas.
5. the "decompilation" of Cockatrice assembly code into **symbolic expressions** needs to be approached a little differently, but I think we could handle this just by repeating the decompilation process for each individual output, and then representing the solution as a series of assignments to each output. But *validate this!*
6. we will absolutely need to write **unit tests** and **regression tests** to check all of these changes against. There may be hidden complexities here.

