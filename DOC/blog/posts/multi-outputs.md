---
title: "Generalizing to Multiple Outputs"
author: Anthony Di Franco
date: 2022-01-21
abstract: "How to support multiple output functions with emphasis on the property testing module."
tags: [planning, draft]
---

The property testing module is currently built around junta checking, which deals with functions with a single output bit only. Multiple output bits can be trivially supported by checking each output bit independently, but this ignores the semantics of how bits group together in words. Also, even when testing bits as if they were independent, it would be desirable to share state among the testing processes for each bit where possible, but unlike in the case of the automatic junta order search, there is no way to do so without knowing or hypothesizing the dependency structure among the output bits.

The genetic search module generates hypotheses for the internal structure of the function under study, which could be used to support identification of the output structure for property testing if the search were extended to encompass output structure. Then, the structure hypothesized by the genetic module could be used to identify and share property computations for common substructures in different hypotheses.
 
