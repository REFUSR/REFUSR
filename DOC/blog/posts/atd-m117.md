---
title: 'REFUSR Meets PAL16L8'
author: "William D. Jones"
tags: [reverse_engineering]
date: 2022-01-29
abstract: "Reverse-engineering the logic equations of a PAL on an old IBM PC memory expansion board."
---

# `ATD M117`

The ATD Model M117 is an ancient memory expansion [ISA](https://en.wikipedia.org/wiki/Industry_Standard_Architecture) card for
IBM PC and compatibles, especially 8088-class systems. The M117 can expand a
system with up to 384kB of 4164-type and 41256-type DRAM, and the address ranges that
the card decodes is configurable using 4 DIP switches. Most of the card's intelligence
is inside a PAL16L8, whose behavior is configured using 3 of the 4 DIP switches.
This is the main reason the card is rather small.

![](img/ATD_M117.jpg)
Picture of my fully-populated ATD M117 card. The PAL is the 20 pin
socketed chip in the center-right. None of the chips were originally
socketed; it took me several tries to find the bad chip :)!

For the longest time, my M117 was broken, and I was not able to figure out why
thanks to not knowing the correct switch settings, which I changed from working
settings long ago. If the switch settings are on [TH99](http://www.uncreativelabs.de/th99/),
I was unable to find them. I knew from when I got the card that it supported at least
384kB of RAM, but 3 banks of 9 DRAM chips each implies that at least one bank will
have 256kB 41256-type DRAM. Not only did I never knew the switch settings, I forgot
_long_ ago which bank(s) should house the 41256 DRAM :).

I thought trying to fix the card would be a good learning experience, so I RE'd
a schematic to figure out the PAL connections (thank goodness for continuity testers!),
and then wrote some gateware to dump the PAL. Documentation on the gateware and
the schematic can be found on [Github](https://github.com/cr1901/ATD_M117).

In fact, the above paragraphs we're copied from the README.md on Github! REFUSR
comes into play because I think it can automate some of the work I did.

## What Is A PAL?

A PAL- or [Programmable Array Logic](https://en.wikipedia.org/wiki/Programmable_Array_Logic)-
is an electrical device consisting of a PROM ([Programmable Read Only Memory](https://en.wikipedia.org/wiki/Programmable_ROM))
and digital logic connected to said PROM that is optimized for implementing
arbitrary digital logic functions. They are useful for replacing tens of smaller
devices implementing AND, OR, NOT, etc primitives in a single package. However,
replacing many smaller primitives means that the PAL becomes effectively a
black box. The PAL's functionality must be extracted from trying all possible inputs
and outputs; tracing a PCB for connections is necessary but not sufficient!

While most pins on a PAL are either inputs or outputs, some pins can be
programmed to be input, output, or bidirectional. I had to infer these pin's
directions from context by tracing which components the PAL pins were connected
to using a continuity meter. And even after I figured out the pinout of the PAL-
a [PAL16L8](https://www.ti.com/lit/ds/symlink/pal16r8am.pdf), to be specific-
I had to create a circuit to read out the PAL's and store the input-to-output
mapping in a text file.

## PAL Pin Mapping

Through tracing connections to the PAL with my continuity tester, I was able
to figure out which pin goes where on my ATD M117. Note that according to the
[datasheet](https://www.ti.com/lit/ds/symlink/pal16r8am.pdf) pins 13-18
inclusive are bidirectional,

The pin functions can be divided into groups:

* `SW1-3` are user-programmable switches (the _only_ user-facing inputs; SW4 is
  not connected to the PAL).
* `A16-A19`, `Delayed /SMEM{R,W}`, `/REFRESH`, `/SMEMR`, and `/SMEMW` are control
  signals from the rest of the computer system to the ATD M117.
* `DRAM A8 All Banks`, `/CAS Bank 3-1`, `/RAS All Banks`, and `/WE All Banks`
  control the DRAM. How the old-style DRAM interface works is beyond the scope
  of this blog post, other than to mention `/CAS Bank 3-1` needs to be [one-hot](https://en.wikipedia.org/wiki/One-hot)
  for proper card operation.
* `Data Bus Direction` is a signal the card uses to control data transfer
  direction between the card and computer.

If you're interested in seeing how all the signals connect together, I provide
[longer-form descriptions](https://github.com/cr1901/ATD_M117/blob/main/signals.md#signal-descriptions)
and an [RE'd schematic](https://github.com/cr1901/ATD_M117/blob/main/schematic.md) on
my Github repo.

|PAL Pin|Signal Name|Pin Direction|
|-------|-----------|-------------|
|1      |SW 1       |I            |
|2      |SW 2       |I            |
|3      |SW 3       |I            |
|4      |A16        |I            |
|5      |A17        |I            |
|6      |A18        |I            |
|7      |A19        |I            |
|8      |Delayed /SMEM{R,W}|I     |
|9      |/REFRESH   |I            |
|10     |GND        |PWR          |
|11     |/SMEMR     |I            |
|12     |DRAM A8 All Banks|O      |
|13     |/CAS Bank 3|O            |
|14     |/CAS Bank 2|O            |
|15     |/CAS Bank 1|O            |
|16     |Data Bus Direction|O     |
|17     |/RAS All Banks|O         |
|18     |/SMEMW     |I            |
|19     |/WE All Banks|O          |
|20     |5V         |PWR          |

## Pal Input/Output Logic Functions

Each of the output pins of a PAL can be represented in terms of a logic function
of the input pins. I dumped the PAL in two formats- a [CSV-formatted](/data/adt.csv)
file for REFUSR that I [gave](/posts/2022-01-10 -- supporting multiple return values in Cockatrice.md) to
Lucca, the other a [text](/data/adt.txt) file for manual analysis using the standard
Unix fare; I _really_ wanted to fix the card there and then!

### Manual Process

The PAL has 11 inputs and 7 outputs- that is 2048 possible inputs I have to
examine for each output! I made the analysis easier by diving the 2048 inputs
into octants- one for each of the 8-possible switch settings (for reasons I
don't remember, _switch settings are the last input bits in the text file, but
the first input bits in the CSV file_).

Let's look at the value of the `/RAS All Banks` signal for all 256 possible
inputs for switch setting `0,0,0`:

```
RAS_BIT_POSITION=13
grep "^0,0,0" adt.csv | cut -d',' -f$RAS_BIT_POSITION | tr --delete '\n'
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111
```

Based on the above, `/RAS All Banks` is usually `0`. Let's extract the input
values for which `/RAS All Banks` is `1` (_remember that bits are reversed
between the text file and CSV_):

```
RAS_BIT_POSITION=2
OUT_IGN1=`expr 7 - $RAS_BIT_POSITION`
OUT_IGN2=`expr 7 - $OUT_IGN1 - 1`
grep -E "000: .{$OUT_IGN1}1.{$OUT_IGN2}" adt.txt
11100000000: 0111111
11100001000: 1111111
11100010000: 0111111
11100011000: 1111111
11100100000: 0111111
11100101000: 1111111
11100110000: 0110111
11100111000: 1110111
11101000000: 0110111
11101001000: 1110111
11101010000: 0111111
11101011000: 1111111
11101100000: 0111111
11101101000: 1111111
11101110000: 0111111
11101111000: 1111111
11110000000: 0111111
11110001000: 0111111
11110010000: 1111111
11110011000: 1111111
11110100000: 0111111
11110101000: 0111111
11110110000: 1110111
11110111000: 1110111
11111000000: 0110111
11111001000: 0110111
11111010000: 1111111
11111011000: 1111111
11111100000: 0111111
11111101000: 0111111
11111110000: 1111111
11111111000: 1111111
```

The last three bits before the colon are the switch settings and therefore don't
matter here. From visual inspection alone, I can tell that `/RAS All Banks` is
only high when the top 3 bits are `1`; the middle 5 bits count out the
binary values from `0` to `31`, and can be treated as don't care.

The top three bits correspond to `/SMEMR`, `/SMEMW`, `/REFRESH` signals
respectively, so I believe that the logic equation for the `/RAS All Banks`
signal for switch setting `000` is:

```
/RAS All Banks == /REFRESH && /SMEMW && /SMEMR
```

In other words, `/RAS All Banks` is only `1` if all of `/SMEMR`, `/SMEMW`, and
`/REFRESH` are _also_ `1`. I know based on how 4164-style DRAM works that this
is a reasonable-looking logic equation for controlling the `/RAS` signal on these
DRAM chips. In fact, the same logic equation is used for all (implemented)
switch settings.

I repeated this process for the `/CAS Bank 3-1` and `A8 DRAM All` signals for
the remaining 7 switch settings to extract their [logic equations](https://github.com/cr1901/ATD_M117/blob/main/switches.md),
and wrote [some](https://github.com/cr1901/ATD_M117/blob/main/dump-octants.sh)
[scripts](https://github.com/cr1901/ATD_M117/blob/main/sel-octant.sh) to help
automate the process. It worked, but is hardly efficient or elegant!

### REFUSR

The above signals were all I needed to RE in order to figure out switch settings
and ultimately fix the card. The PAL was fine, there was another chip that was
indeed bad. However, without REing the PAL, I would've not have had enough
information to know which signals weren't working because of incorrect switch
settings and which signals were wrong because of a bad chip.

I deliberately did not RE the `/WE All Banks` nor `Data Bus /OE` signals yet.
I have left these signals for REFUSR to solve, and to compare to the signals
I _have_ already RE'd as a test for REFUSR! If REFUSR can extract the same
logic equations (if not necessarily fully reduced) for the above outputs as
I did via the manual process, I will be confident that the logic equations that
REFUSR finds for `/WE All Banks` and `Data Bus /OE` are also correct.

## Future Directions
The PAL16L8 is an "unregistered" device- meaning it does not hold any internal
state, and the output pins values are completely determined by the input pins'
values. It is possible to represent a registered PAL- such as the PAL16R8- in
terms of an input/output mapping table that REFUSR can handle. However, I'm still
unsure how I would create gateware to extract (or infer) the internal PAL state.
