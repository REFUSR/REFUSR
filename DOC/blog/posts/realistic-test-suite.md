---
title: "A Test Suite of Functions with More Microcontroller-Like Features"
author: Anthony Di Franco
date: 2022-01-21
abstract: "Establishing a test suite with more realistic microcontroller-like examples. Drawing from symbolic regression benchmarks where appropriate."
tags: [planning]
---

# Preliminaries

Microcontroller code commonly deals with single-bit flags, which are already supported by REFUSR, but also with multiple bit patterns such as integers in accumulators or timers. To support these, identifying them in inputs and supporting them as function outputs are both needed. Supporting multi-bit outputs is addressed elsewhere, so here I will focus on identifying correlated bit patterns in inputs.

# identifying Correlated Input Bits

At one extreme, second order correlations can be sought by looking at the covariance statistics of input bits, perhaps conditional on the output value. At the other extreme, common bit patterns can be identified in the entire input vector by prototype-finding methods such as k-means clustering of input bit vectors, again perhaps conditional on the output value. The true correlation structure among the input bits is exactly represented by the white box function structure which is hypothesized in symbolic regression of the function, and in a sense lies between these two extremes.

A manual way of specifying the structure of the input bit vector would be a subset of a system for representing the full internal structure of the function, and could be useful as a way for a user of the REFUSR tool to provide constraints on, or side information to, the REFUSR search.

# Tests

Some tests that would be suitable for ‘minimum viable’ multi-bit function support are the following:

 * Simply Incrementing Accumulator (timer, counter)
 * Arithmetic on  Integers
