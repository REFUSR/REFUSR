---
title: "Reverse Engineering the Velocio Protocol"
author: Olivia Lucca Fraser
date: 2021-01-01
tags: [protocol, reversing, plc, velocio]
abstract: "Some early working notes I took while reverse engineering Velocio's proprietary protocol (over Modbus)"
---

# Observations

## Header/magic: `56 ff ff 00`

A transmission to the device may contain several messages, each prefixed by this header: `56 ff ff 00`.

Here's the contents of a small, compiled vBuilder program:

``` example
julia> split(b, "\x56\xff\xff\x00")
27-element Array{SubString{String},1}:
 "\0\0\0\x9d\0\0\0\x1a\a"
 "\0\xf1\x02\x06"
 "\0\xaaL"
 "\0\x12\xff\xff\x10\0\xff\xff\xff\xff\xff\xffvProject.viof           \x06\x06\0\0\0\0\0\0\0\0\0\0\0\0\0\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\f"
 "\0P\0\0\0\0\0\0>"
 "\0\xab\0\0\0\r\0\0\0\0\0\0\0\0\0\0\0\0\0\0\xff\xff\xff\xff\0\0\xff\xff\xff\xff\0\0\0\x03\0\0\0\0\0\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x17"
 "\0\x01\0\x01\x06\0\0\0\x81\x01\0\0\0\0\x01\0\x01\0\x02\x15"
 "\0\x01\0\x02\x05\0\0\x80\xc1\x01\0\0\x01\0\x01\0\0\x15"
 "\0\x01\0\x03\x05\0\0\x80\xc2\x01\0\0\x01\0\x01\0\0\$"
 "\0\t\0\x01InBitC1         \x01\0\0\0\0\x01\0\0\xff\xffb\x01\$"
 "\0\t\0\x02InBitC2         \x01\0\0\0\0\x02\0\0\xff\xffb\x02\$"
 "\0\t\0\x03InBitC3         \x01\0\0\0\0\x04\0\0\xff\xffb\x03\$"
 "\0\t\0\x04InBitC4         \x01\0\0\0\0\b\0\0\xff\xffb\x04\$"
 "\0\t\0\x05InBitC5         \x01\0\0\0\0\x10\0\0\xff\xffb\x05\$"
 "\0\t\0\x06InBitC6         \x01\0\0\0\0 \0\0\xff\xffb\x06\$"
 "\0\t\0\aOutBitD1        \x01\0\0\x01\0\x01\0\0\xff\xffC\x01\$"
 "\0\t\0\bOutBitD2        \x01\0\0\x01\0\x02\0\0\xff\xffC\x02\$"
 "\0\t\0\tOutBitD3        \x01\0\0\x01\0\x04\0\0\xff\xffC\x03\$"
 "\0\t\0\nOutBitD4        \x01\0\0\x01\0\b\0\0\xff\xffC\x04\$"
 "\0\t\0\vOutBitD5        \x01\0\0\x01\0\x10\0\0\xff\xffC\x05\$"
 "\0\t\0\fOutBitD6        \x01\0\0\x01\0 \0\0\xff\xffC\x06\$"
 "\0\t\0\rvFactoryPage    !\0\0\0\0\0\0\0\xff\xff\x9f\xff\x1f"
 "\0\xf4\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\a"
 "\0\xf0\x01\x06"
 "\0\xf3\n"
 "\0\xf6\xb4\0\0\xe6\a"
 "\0\xf1\x01"
```

## Function Code/Function type

Byte 2 appears to be a function code. Note the similarity in structure of messages that share an function code.

``` example
julia> [m[2] for m in msgs] |> sort |> unique
12-element Array{UInt8,1}:
 0x00
 0x01
 0x09
 0x12
 0x50
 0xaa
 0xab
 0xf0
 0xf1
 0xf3
 0xf4
 0xf6
```

### Function Code 0x09: Connections

All of the messages that contain human-readable ASCII substrings, with the exception of the function code 0x12 message that contains the flow chart's file name, use function code 0x09.

Most of these appear to concern the input and output pins (InBitC1 ??? InBitC6, and OutBitD1 ??? OutBitD6). The last concerns what's called the "vFactoryPage".

Offset 4 seems to be a sequence number:

``` example
julia> [m[4]|>Int for m in m9]
13-element Array{Int64,1}:
  1
  2
  3
  4
  5
  6
  7
  8
  9
 10
 11
 12
 13
```

At offset 5, we have a fixed-width, 16-byte name field, padded with space characters (0x20).

That takes us to offset 21. Here are the remaining bytes in each message:

``` example
[0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0xff, 0xff, 0x62, 0x01, 0x24]
[0x01, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0xff, 0xff, 0x62, 0x02, 0x24]
[0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0xff, 0xff, 0x62, 0x03, 0x24]
[0x01, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0xff, 0xff, 0x62, 0x04, 0x24]
[0x01, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0xff, 0xff, 0x62, 0x05, 0x24]
[0x01, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0xff, 0xff, 0x62, 0x06, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xff, 0x43, 0x01, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0xff, 0xff, 0x43, 0x02, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x04, 0x00, 0x00, 0xff, 0xff, 0x43, 0x03, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00, 0x00, 0xff, 0xff, 0x43, 0x04, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x10, 0x00, 0x00, 0xff, 0xff, 0x43, 0x05, 0x24]
[0x01, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0xff, 0xff, 0x43, 0x06, 0x24]
[0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0x9f, 0xff, 0x1f]
```

All of these, except for the vFactoryPage message, which begins with 0x21, begin with 0x01.

Then we have two null bytes, and then: the OutBit messages have a 1, while all the others have 0.

Then another null byte, and something interesting: a repeated sequence, which occurs once for the six InBit messages, and once for the six OutBit messages. It's a bit-flag identifier.

``` example
julia> [log(2, m[26])|>Int for m in m9[1:end-1] ]
12-element Array{Int64,1}:
 0
 1
 2
 3
 4
 5
 0
 1
 2
 3
 4
 5

```

Similar identifiers are used in the velocio protocol "set bit" commands. This is what the `mask` variable does in this bit of Julia code I wrote:

``` julia

GAP = 0x00
PREFIX = [0x56, 0xff, 0xff, 0x00]

function mk_write_command(bits, on)
    @assert all(1 <= i <= 6 for i in bits)
    mask = sum(1<<(i-1) for i in bits)
    cmd = [
        PREFIX...,
        0x15, 0x11, 0x01, 0x00, 0x01, 0x00, 0x00, 0x09, 0x01,
        0x00, 0x00, 0x01, 0x00, GAP, 0x00, 0x00, GAP,
    ]
    cmd[18] = mask
    cmd[21] = UInt8(on)
    return cmd
end
```

Byte 12 contains 0x62 for input pins, and 0x43 for output pins.

Byte 13 gives us the pin index, again, but as an integer, not as a bitshifted flag.

1.  as XML
    
    These 0x09 messages seem to be a translation of the `<Connections>` node of the XML document:
    
    ``` xml
    <Connections>
      <Connection sKey="vFactoryPage" bRemoteWritable="True" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="UI16" dataSource="register" />
      <Connection sKey="InBitC1" iPort="2" iPin="1" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="InBitC2" iPort="2" iPin="2" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="InBitC3" iPort="2" iPin="3" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="InBitC4" iPort="2" iPin="4" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="InBitC5" iPort="2" iPin="5" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="InBitC6" iPort="2" iPin="6" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="input" />
      <Connection sKey="OutBitD1" iPort="3" iPin="1" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
      <Connection sKey="OutBitD2" iPort="3" iPin="2" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
      <Connection sKey="OutBitD3" iPort="3" iPin="3" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
      <Connection sKey="OutBitD4" iPort="3" iPin="4" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
      <Connection sKey="OutBitD5" iPort="3" iPin="5" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
      <Connection sKey="OutBitD6" iPort="3" iPin="6" ui32Mask="0" ui32MessageId="0" ui32Period="0" dataType="Bit" dataSource="output" />
    </Connections>
    ```

### Function Code 0x15: Set pins

``` julia
GAP = 0x00
PREFIX = [0x56, 0xff, 0xff, 0x00]

function mk_write_command(bits, on)
    @assert all(1 <= i <= 6 for i in bits)
    mask = sum(1<<(i-1) for i in bits)
    cmd = [
        PREFIX...,
        0x15, 0x11, 0x01, 0x00, 0x01, 0x00, 0x00, 0x09, 0x01,
        0x00, 0x00, 0x01, 0x00, GAP, 0x00, 0x00, GAP,
    ]
    cmd[18] = mask
    cmd[21] = UInt8(on)
    return cmd
  end
```

### Function Code 0x08: Read pins

``` julia
function mk_read_command(bit, output=false)
    cmd = [PREFIX..., 0x08, 0x0a, GAP, 0x01]
    idx = output ? bit + 6 : bit
    cmd[8] = idx
    return cmd
end
```

### Function Code 0x07: Control

``` julia
CONTROL_COMMANDS =
    [
        # control instructions
        "pause"       => [PREFIX..., 0x07, 0xf1, 0x02],
        "play"        => [PREFIX..., 0x07, 0xf1, 0x01],
        "reset"       => [PREFIX..., 0x07, 0xf1, 0x06],
        "step_into"   => [PREFIX..., 0x07, 0xf1, 0x03],
        "step_out"    => [PREFIX..., 0x07, 0xf1, 0x04],
        "step_over"   => [PREFIX..., 0x07, 0xf1, 0x05],
        "enter_debug" => [PREFIX..., 0x07, 0xf0, 0x02],
        "exit_debug"  => [PREFIX..., 0x07, 0xf0, 0x01],
    ] |> Dict
```
