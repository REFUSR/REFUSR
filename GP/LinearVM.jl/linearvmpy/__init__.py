##################################
# Python Wrapper for LinearVM.jl #
##################################

###
# The easiest way to get this to work, it seems, is to evaluate it with
# python-jl, a binary provided by the julia python package. You can
# install that package with `pip3 install julia`.
##

import os
from random import choice
from pathlib import Path
from julia import Main
# Activate the Julia package at ..
Main.eval(f"""using Pkg; Pkg.activate("{Path(__file__).parent.parent}")""")
# Now import the LinearVM package
from julia import LinearVM

#################################################################
# Some convenience functions for testing and debugging purposes #
#################################################################
def random_program(length, num_data, num_registers, opstr="& | xor mov ~"):
    return LinearVM.random_program(length, opstr=opstr)

def random_program_strs(length, num_data, num_registers, opstr="& | xor mov ~"):
    ops = opstr.split()
    srcs = list(range(-num_data, 0)) + list(range(1, num_registers+1))
    dsts = list(range(1, num_registers+1))
    return [f"{choice(ops)} {choice(dsts)} {choice(srcs)}" for _ in range(length)]

def fake_data(n):
    return Main.eval(f"""BitArray(rand(Bool, 2^{n}, {n}))""")


def quicktest(code_len=32, num_registers=8, num_data=8, out_registers=[1]):
    code = random_program_strs(code_len, num_registers, num_data)
    s_code = '\n'.join(code)
    print(f"--- Sample code ---\n{s_code}")
    data = fake_data(8)
    print(f"--- Sample data ---")
    Main.println(data)
    print("--- Executing ---")
    results, trace = execute(code, data, out_registers=out_registers, num_registers=num_registers)
    print("--- Results ---")
    Main.println(results)
    print("--- Trace ---")
    Main.println(trace)
    return 


def onehot_decode(onehot_code):
    # TODO
    ...
    raise(Exception("Unimplemented"))
    # Faster to decode on the julia side? we can worry about optimizations later, i guess.


def execute_onehot_code(onehot_code, data, out_registers=[1], num_registers=None):
    code = onehot_decode(onehot_code)
    return execute(code, data, out_registers, num_registers)


#################################################################
# This is the main entry point to the VM. 
#################################################################
def execute(code, data, out_registers=[1], num_registers=None):
    if num_registers is None:
        num_registers = Main.size(data,2)
    return LinearVM.execute(code, 
            data, 
            out_registers=out_registers, 
            num_registers=num_registers)



def make_unit_test_table(n, csv="testdata.csv"):
    code_len = 32
    num_registers = 4
    num_data = 4
    out_registers = [1,2]
    with open(csv, "w") as fd:
        fd.write("num_data, num_registers, output_registers, program, num_cases, input_data, output\n")
        for i in range(n):
            prog = random_program_strs(code_len, num_data, num_registers)
            data = fake_data(num_data)
            output, trace = execute(prog, data, out_registers, num_registers=num_registers)
            prog_s = ';'.join(prog)
            out_s = ''.join(str(int(x)) for x in Main.vec(output))
            data_s = ''.join(str(int(x)) for x in Main.vec(data))
            fd.write(f"{num_data},{num_registers},{out_registers},{prog_s},{2**num_data},{data_s},{out_s}\n")
