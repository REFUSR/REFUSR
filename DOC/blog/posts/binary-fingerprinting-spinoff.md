---
title: "Binary Fingerprinting with Hyperdimensional Codes"
author: Anthony Di Franco
date: 2022-01-21
abstract: "How one might spin off the function fingerprinting techniques into binary fingerprinting, binwalk-style per Sergey's suggestion."
tags: [planning, draft]
---

# Binwalk

[Binwalk](https://github.com/ReFirmLabs/binwalk) is a binary fingerprinting program aimed at firmware extraction and analysis, similar to the unix `file` command, but with a much more sophisticated feature set, and a python API for scripted use. Among its distinctive features are entropy analysis and recursive decompression suitable for working with archives and other compressed files.

# Binwalk-like fingerprinting

Binwalk works with binary files as such, and does not deal with their behavior when executed, while REFUSR is meant to identify functions based on their observed execution behavior. The fingerprinting developed for REFUSR solves a subproblem in the identification of functions by input-output similarity by computing fixed-size representations of their input-output overlap on arbitrarily large sample sets via Hyperdimensional codes.

By replacing input-output samples with substrings of files, files could be hashed in a way that reflects their contents and permits content-based comparison. This is a distinct feature from the ones currently offered by Binwalk and the usefulness of it to users of Binwalk would have to be assessed and confirmed or a separate tool made for a different clientele. It also likely overlaps with techniques used for virus scanning, image file fingerprinting, and other content-based hashing, but is likely more principled and transparent in its operation than some of those techniques, such as locality-sensitive hashing and neural hashing.
