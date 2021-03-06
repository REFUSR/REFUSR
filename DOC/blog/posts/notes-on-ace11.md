---
title: "Notes on the ACE 11 PLC"
tags: [plc, hardware]
author: "Steve 'Dillo' Okay"
abstract: "Some early notes on the ACE 11 PLC, which we had initially considered as a target for REFUSR."
date: 2020-12-01
---

# What is the ACE 11?

The ACE 11 is a small PLC, with 6 digital in/outputs, that runs off either a USB port or a 2-pin 5V power supply. Its 2.5 inches by 2.5 inches by 0.5 inches. It supports Ladder Logic, Flow Chart and Object Oriented programming, and talks Modbus over USB for receiving programs and getting/supplying values to HMIs (Human Machine Interfaces). The digital outputs can handle 3 - 30 VDC, 300 mA and the digital inputs can handle 3 - 30 VDC. The MCU (Microcontroller) in the PLC is a Texas Instrument 32-bit ARM Cortex-M4F, [TM4C123H6PM](https://www.ti.com/product/TM4C1232H6PM), which runs at 80MHz. It has 256kB Flash memory, 2 kB EEPROM, 32 kB SRAM and two 12-bit ADC modules. It runs in Thumb-2 mode, which means it has a mixed 16/32-bit instruction set. It also features a 16-bit SIMD vector processing unit, six 32-bit timers (that can be split to 12 16-bit timers) and six 64-bit timers (that can be split to 12 32-bit timers) with real-time clock capability. Alongside that it also has a MPU (Memory Protection Unit) and a single-precision capable FPU (Floating-Point Unit).

# Where is the ACE 11 used?

Velocio Networks targets the ACE line of PLC devices towards everything from hobbyists and small start-ups to large companies that need a flexible and cost-effective solution to deploy a PLC controlled system. There is also the Branch line of PLCs that Velocio Networks offers, that is designed to make larger PLC systems easier to accomplish, by making the PLCs into a distributed system, with a master-worker relation between a master device and the rest of the PLCs.

The ACE line of PLCs are specifically made for smaller implementations, where you have a localized process that needs to be controlled by a single PLC that has between 3 - 12 analogue inputs, 3 - 18 digital inputs, 2 - 4 thermal/differential analogue inputs, 3 - 24 digital outputs and 1 - 2 RS232/RS485 connectors. One example is a container company (ColdBox) that makes temperature controlled transport containers, where a ACE PLC was put as the heart of the temperature regulation system. It was responsible both for the actual regulation of the system, but also external communication through a touchscreen and a cellular modem, showing the flexibility of the ACE PLCs.

Its small device footprint makes it ideal for situations where there isn't that much space in control boxes or in the area of the devices the PLC is going to control. They also offer embedded PLCs, for custom hardware projects where you want to integrate a PLC on a custom PCB.

# How is the ACE 11 programmed

The main software used to make the Ladder Logic or Flow Chart programs that is then run on ACE or Branch PLCs is called [vBuilder](http://velocio.net/vbuilder) and is provided completely free of charge by Velocio Networks. It has a easy to use interface and a [good manual](http://velocio.net/wp-content/uploads/2016/01/vBuilder-Manual.pdf) to get started even for a novice. It comes both as 32 and 64-bit program and is compatible with Windows from Windows Vista up to Windows 10. The manual contains 4 examples, 2 for making a Flow Chart program and 2 for making a Ladder Logic program, amongst the standard manual contents that showcases the interface of vBuilder and how you do different things in the UI. A notable feature for both ACE and Branch PLCs is that they support a more, modern Object Oriented Programming approach, where you can code objects and subroutines to be used. This makes it easier to structure the programs and enables easier code reuse.

The programs that are built with vBuilder can either be compiled to a file, that you then provision the PLC with through a USB connection, or you integrate the PLC with vBuilder and run the code interactively. With the interactive option, you can single step, debug and get a overview of your program as it is running on the PLC. You can stop the program any time and look at the current memory and IO state. They also offer a software that is called [vFactory](http://velocio.net/vfactory), that is aimed towards designing HMIs that visualize the state of the process that the program that is running on a PLC is in. Its a drag-n-drop interface where you choose the type of visualisation you want, drag it to where you want it on a grid and then you configure the properties that it should have, i.e. what tag it should take its data from in the program its monitoring, what colour the control should have and similar properties. For the graph-like visualisations you can also choose boundries of the value its monitoring, to have it show different colours depending on the value. There is also a companion software called [vFactory Viewer](http://velocio.net/vFactory%20Viewer.exe) if you're only interested in viewing a HMI that has been built with vFactory instead of both viewing and editing it.

Besides the manufacturers own software, all of their PLCs are also programmable with the different [InduSoft](http://velocio.net/indusoft/) software available from Aveva.

As the PLCs speak plain Modbus over USB, they can interface with, and be programmed by, any software or hardware that can access a PLC over Modbus over USB. The manufacturer has a [Modbus example](http://velocio.net/modbus-example/) that showcases a Visual Studio made form, programmed in C\#, that connects to a Velocio PLC to get/set values.

In addition to the free software used to program both the PLC and HMIs, the manufacturer also supplies 11 [tutorials](http://velocio.net/tutorials/) to get started with programming their PLCs, 3 [tutorials](http://velocio.net/tutorials) to get started with making HMIs (mainly targeted at the HMI hardware that they also sell, [Command HMI](http://velocio.net/hmi/)) and 5 [tutorials](http://velocio.net/hmi/) that shows how to integrate with different motor controls or other equipment like a scale used to weigh things.

# Using the ACE 11 to generate datasets

The ACE 11 will be the main generator for datasets for our algorithms to explore through coding several programs programmed in Ladder Logic, Flow Chart and Object Oriented programming in vBuilder and let the algorithms analyze the binaries and see if they can recover what symbols are in the binaries. vBuilder has the capability of compiling the code and save it in a binary file instead of directly uploading it to a PLC, which makes it easier for us to get our hands on the binaries to analyze. By knowing what instruction set the MCU runs, we can let the algorithms figure out how the instruction set is used to represent for example a timer or switching an output on/off.

That the THUMB-2 instruction set is a mixed 16/32-bit instruction set means that the state space to cover isn't too large, also the fact that its focus is on code-density and thus only includes a subset of the full ARM instruction set means the state space is even more reduced.

That vBuilder has the ability to output the compiled code into binaries means that we can easily generate a large corpus to feed as data to the algorithm to train it. It also means that we don't need to instrument a USB capturing tool to be able to capture the binary as its sent to the PLC for execution.

We aim to be able to both dissect the binaries and get a understanding of how the PLC programming language uses the Cortex-M4F to run its programs and be able to analyze the PLC while running the code and see if the algorithms can recover what is being executed in terms of symbols. PLC languages are usually fairly bit-oriented and thus can be approached like boolean algebraic equations in most parts. Language features like timers and counters are important for the logic of a program, but don't neccessarily fit well into boolean algebra, which will be a challenge to tackle.

The generated binaries will also be used to manually reverse engineer the symbol to machine code relation to see if there is anything that can be found regarding relations between type of symbol and the type of instructions used by the compiler to execute that symbol. A big difference between the ARM instruction set and the Thumb-2 instruction set is that almost all instructions in Thumb-2 are unconditional and instead Thumb-2 have a special If-Then instruction to use to make conditionals. This reduces the complexity of reverse engineering the machine code.
