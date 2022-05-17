module LinearVM

using Printf
using AxisArrays
using FunctionWrappers: FunctionWrapper

export execute_vec, Inst, mov, get_effective_indices, strip_introns, truth, falsity, compile_vm_code, random_program, random_inst


const mov = identity
const VMOUT_t = Union{Vector{Bool}, BitVector}
const VMIN_t  = Tuple{Union{Vector{Bool}, BitVector}}


constant(c) = c ? truth : falsity

truth() = true
falsity() = false

struct Inst
    op::Function
    arity::Int
    # let's use the convention that negative indices refer to input
    dst::Int
    src::Int
end

function Inst(opstr, dst::Integer, src::Integer)
    op = Symbol(opstr)
    arity = lookup_arity(op)
    if dst == 0 || src == 0
        error("0 is an invalid register index")
    end
    if dst < 0
        error("Destination register musn't be immutable")
    end
    Inst(eval(op), arity, Int(dst), Int(src))
end

## Decode instructions written like 
## "xor 4 -2"
## or the pretty way
## "R[04] ← R[04] xor D[02]"

function Inst(s::String)
    if '←' ∈ s || '=' ∈ s
        assignment_token = '←' ∈ s ? '←' : '='
        dstx, right = split(s, assignment_token)
        opstr, srcx = split(right)[end-1:end]
        # We encode data registers with negative integers
        dn = parse(Int, filter(isdigit, dstx)) * (dstx[1] == 'D' ? -1 : 1)
        sn = parse(Int, filter(isdigit, srcx)) * (srcx[1] == 'D' ? -1 : 1)
    else
        opstr, dststr, srcstr = split(s)
        dn = parse(Int, dststr)
        sn = parse(Int, srcstr)
    end
    Inst(opstr, dn, sn)
end



@inline function lookup_arity(op_sym::Symbol)
    table = Dict(:⊻ => 2, :xor => 2, :| => 2, :& => 2, :nand => 2, :nor => 2, :~ => 1, :mov => 1, :identity => 1)
    try
        return table[op_sym]
    catch e
        @warn "$(op_sym) not in arity table. assuming 2"
        return 2
    end
end

function decode_ops(opstr)
    Symbol.(split(opstr))
end 

function random_inst(; ops, num_data = 1, num_registers = num_data)
    op = rand(ops)
    arity = lookup_arity(op)
    dst = rand(1:num_registers)
    src = rand(Bool) ? rand(1:num_registers) : -1 * rand(1:num_data)
    Inst(eval(op), arity, dst, src)
end

function random_program(n; ops=nothing, opstr=nothing, num_data = 1, num_registers = 1)
    if !isnothing(opstr)
        ops = decode_ops(opstr)
    end
    [random_inst(;ops, num_data, num_registers) for _ = 1:n]
end

## How many possible Insts are there, for N inputs?
## Where there are N inputs, there are 2N possible src values and N possible dst
## arity is fixed with op, so there are 4 possible op values
number_of_possible_insts(n_input, n_reg; ops) = n_input * (n_input + n_reg) * length(ops)


function number_of_possible_programs(n_input, n_reg, max_len)
    [number_of_possible_insts(n_input, n_reg)^BigFloat(i) for i = 1:max_len] |> sum
end

function number_of_possible_programs(config::NamedTuple)
    number_of_possible_programs(
        config.genotype.data_n,
        config.genotype.registers_n,
        config.genotype.max_len,
    )
end


@inline function semantic_intron(inst::Inst)::Bool
    inst.op ∈ (&, |, mov) && (inst.src == inst.dst)
end


function get_effective_indices(code, out_regs)
    active_regs = copy(out_regs)
    active_indices = []
    for (i, inst) in reverse(enumerate(code) |> collect)
        semantic_intron(inst) && continue
        if inst.dst ∈ active_regs
            push!(active_indices, i)
            filter!(r -> r != inst.dst, active_regs)
            inst.arity == 2 && push!(active_regs, inst.dst)
            inst.arity >= 1 && push!(active_regs, inst.src)
        end
    end
    reverse(active_indices)
end


function strip_introns(code, out_regs)
    #code[get_effective_indices(code, out_regs)] # use a view?
    view(code, get_effective_indices(code, out_regs))
end

Base.isequal(a::Inst, b::Inst) =
    (a.op == b.op && a.arity == b.arity && a.dst == b.dst && a.src == b.src)


function Inst(d::Dict)
    op = d["op"] isa Number ? constant(d["op"]) : eval(Symbol(d["op"]))
    Inst(op, d["arity"], d["dst"], d["src"])
end


function Base.show(io::IO, inst::Inst)
    op_str = inst.op == identity ? "mov" : (inst.op |> nameof |> String)
    regtype(x) = x < 0 ? 'D' : 'R'
    if inst.arity == 2
        @printf(
            io,
            "%c[%02d] ← %c[%02d] %s %c[%02d]",
            regtype(inst.dst),
            inst.dst,
            regtype(inst.dst),
            inst.dst,
            op_str,
            regtype(inst.src),
            abs(inst.src)
        )
    elseif inst.arity == 1
        @printf(
            io,
            "%c[%02d] ← %s %c[%02d]",
            regtype(inst.dst),
            inst.dst,
            op_str,
            regtype(inst.src),
            abs(inst.src)
        )
    else # inst.arity == 0
        @printf(io, "%c[%02d] ← %s", regtype(inst.dst), inst.dst, inst.op())
    end
end


@inline I(ar, i) = ar[mod1(abs(i), length(ar))]
@inline IV(ar, i) = view(ar, mod1(abs(i), length(ar)), :)

function evaluate_inst!(; regs, data, inst, debug)
    s_regs = inst.src < 0 ? data : regs
    d_regs = regs
    if inst.arity == 2
        args = [I(d_regs, inst.dst), I(s_regs, inst.src)]
    elseif inst.arity == 1
        args = [I(s_regs, inst.src)]
    else # inst.arity == 0
        args = []
    end
    if debug
        @printf "%-30s %s %s\n" inst regs data
    end
    d_regs[inst.dst] = inst.op(args...)
end


## TODO: Optimize this. maybe even for CUDA.
# The indexing is slowing things down, I think.
# vectoralize it further.
function evaluate_inst_vec!(; R, D, inst)
    # Add a dimension to everything
    s_regs = inst.src < 0 ? D : R
    d_regs = R
    if inst.arity == 2
        d_regs[inst.dst, :] .= inst.op.(IV(d_regs, inst.dst),
                                        IV(s_regs, inst.src))
    elseif inst.arity == 1
        d_regs[inst.dst, :] .= inst.op.(IV(s_regs, inst.src))
    else
        d_regs[inst.dst, :] .= inst.op()
    end

end


# TODO: use axis arrays
function execute_seq(code, data; config=nothing, num_registers=1, max_steps=Inf, out_registers=[1], make_trace = true, debug = false)::Tuple{Vector{Bool},BitArray}
    if !isnothing(config)
        num_registers = config.genotype.registers_n
        out_registers = config.genotype.output_reg
        max_steps = config.genotype.max_steps
    end
    regs = zeros(Bool, num_registers) |> BitVector
    trace_len = Int(max(1, min(length(code), max_steps))) # Assuming no loops
    trace = BitArray(undef, num_registers, trace_len)
    steps = 0
    if debug
        @printf "%-30s %s %s\n" "INITIALIZING" regs data
    end
    for (pc, inst) in enumerate(code)
        if pc > max_steps
            break
        end
        evaluate_inst!(; regs, data, inst, debug)
        if make_trace
            trace[:, pc] .= regs
        end
        steps += 1
    end
    regs[out_registers], trace
end


function execute_vec(code, INPUT; config=nothing, out_registers=nothing, num_registers=nothing, max_steps=length(code), make_trace = true)
    if !isnothing(config)
        max_steps = config.genotype.max_steps
        out_registers = config.genotype.output_reg
        num_registers = config.genotype.num_registers
    end 
    D = INPUT'
    R = BitArray(undef, num_registers, size(D, 2))
    R .= false
    trace_len = max(1, min(length(code), max_steps))
    trace = BitArray(undef, size(R)..., trace_len)
    pcaxis = Vector{Union{Int64,Symbol}}(1:size(trace,3))
    pcaxis[end] = :end
    trace = AxisArray(
        trace,
        reg = 1:size(trace, 1),
        case = 1:size(trace, 2),
        pc = pcaxis,
    )
    steps = 0
    for (pc, inst) in enumerate(code)
        if pc > max_steps
            break
        end
        evaluate_inst_vec!(;R, D, inst)
        if make_trace
            trace[pc = pc] = R
        end
        steps += 1
    end
    R[out_registers, :], trace
end


function compile_vm_code(code; config=nothing, num_registers=nothing, out_registers=nothing, debug=false)
    if !isnothing(config)
        out_registers = config.genotype.out_registers
    end
    eff_ind = get_effective_indices(code, out_registers)
    eff = code[eff_ind]
    function (data)
        execute_seq(eff, data; config, num_registers, out_registers, debug) |> first 
    end |> FunctionWrapper{VMOUT_t, VMIN_t}
end


unzip(a) = map(x -> getfield.(a, x), fieldnames(eltype(a)))

function evaluate_sequential(code; INPUT, config::NamedTuple, make_trace = true)
    res, tr =
        [
            execute_seq(code, row, config = config, make_trace = make_trace) for
            row in eachrow(INPUT)
        ] |> unzip
    (res, cat(tr..., dims = (3,)))
end

# TODO transpose the output so that cases are represented by rows not columns

function execute(code::Vector{Inst}, input; num_registers=size(input, 2), out_registers=[1])
    effective_code = strip_introns(code, out_registers)
    execute_vec(code, input; num_registers, out_registers)
end

function execute(code::Vector{String}, input; num_registers=size(input, 2), out_registers=[1])
    execute(Inst.(code), input; num_registers, out_registers)
end

end