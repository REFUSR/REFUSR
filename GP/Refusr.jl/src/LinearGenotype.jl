module LinearGenotype

using Printf
using AxisArrays
using Distributed
using StatsBase
using FunctionWrappers: FunctionWrapper
import JSON
import Base.isequal

using ..Ops
using ..Names
using ..StructuredTextTemplate
using ..Cockatrice.Evo
using ..Expressions
using ..LinearVM


const RegType = Bool
const Exp = Expressions


const Fitness = NamedTuple{
    (:scalar, :dirichlet, :ingenuity, :information, :parsimony),
    Tuple{Float64, Float64, Float64, Float64, Float64}
}

function NewFitness()
    Fitness((-Inf, -Inf, -Inf, -Inf, -Inf))
end






@inline function lookup_arity(op_sym)
    table = Dict(:xor => 2, :| => 2, :& => 2, :nand => 2, :nor => 2, :~ => 1, :mov => 1, :identity => 1)
    try
        return table[op_sym]
    catch e
        @warn "$(op_sym) not in arity table. assuming 2"
        return 2
    end
end

# TODO set up configurable ops
# debug new decompiler bug


# const OPS = [
#     (⊻, 2),
#     #(⊃, 2),
#     #(nand, 2),
#     (|, 2),
#     (&, 2),
#     (~, 1),
#     (mov, 1),
#     #    (truth, 0),
#     #    (falsity, 0), 
# ]





#####
## Decode a binary encoded instruction -- not yet in use
## format:
## [opcode][dst][src][is src data or reg? bit]
## arity is always 2
#####
function binInst(bv, num_reg, num_data)
    op = function (a, b)
        # I fear this is a bit inefficient, and possibly
        # awkward to vectorialize
        i = (Int(a) << 1) | Int(b)
        bv[i]
    end |> FunctionWrapper{Bool, Tuple{Bool, Bool}}
    ptr = 5
    dstbits = ceil(log2(num_reg)) |> Int
    dst = bv[ptr:(ptr+dstbits)] |> packbits
    ptr += dstbits
    srcbits = max(log2(num_reg), log2(num_data)) |> ceil |> Int
    src = bv[ptr:(ptr+srcbits)] |> packbits
    ptr += srcbits
    if bv[ptr]
        src *= -1
    end

    Inst(
        op,
        2,
        dst,
        src,
    )
end


function serialize_op(inst::Inst)
    if inst.arity == 0
        inst.op()
    else
        nameof(inst.op)
    end
end

function JSON.lower(inst::Inst)
    (op = serialize_op(inst), arity = inst.arity, dst = inst.dst, src = inst.src)
end






function to_expr(
    code::Vector{Inst};
    incremental_simplify = true,
    alpha_cache = true,
    threshold = 5,
    output_reg = [1],
    )

    exprs = [to_expr_by_output_reg(code;
                                   intron_free=false,
                                   incremental_simplify,
                                   alpha_cache,
                                   threshold,
                                   reg=o) for o in output_reg]
    # now fold them, and simplify
    @show seq(a,b) = :($a ; $b)
    e = reduce(seq, exprs)
    filter!(a -> !(a isa LineNumberNode), e.args)

    return e
end


function to_expr_by_output_reg(
    code::Vector{Inst};
    intron_free = false,
    incremental_simplify = true,
    alpha_cache = true,
    threshold = 5,
    reg = 1,
)
    DEFAULT_EXPR = false
    code = intron_free ? copy(code) : strip_introns(code, [reg])
    if isempty(code)
        return DEFAULT_EXPR
    end
    expr = pop!(code) |> inst_to_expr
    # if the final instruction in the code is just R[1] := R[1] ⊻ R[1]
    # then the program codes for `x -> false`. nothing else matters here.
    LHS, RHS = expr.args
    @show LHS == :(R[$reg])
    if RHS isa Bool
        return RHS
    end
    while !isempty(code)
        @show e = pop!(code) |> inst_to_expr
        lhs, rhs = e.args
        @show RHS = Expressions.replace(RHS, lhs => rhs)

        if incremental_simplify && count_subexpressions(RHS) > threshold
            # We only need to simplify again if rhs has common variables with RHS minus lhs
            RHS_minus_lhs = Exp.replace(RHS, lhs => :XYZZY)
            if rhs isa Bool || Exp.shares_variables(RHS_minus_lhs, rhs)
                RHS = Exp.simplify(RHS; alpha_cache)
            end
        end
    end
    # Since we initialize the R registers to `false`, any remaining R references
    # can be replaced with `false`.
    RHS = Expressions.replace(RHS, (e -> e isa Expr && e.args[1] == :R) => false)
    if incremental_simplify
        RHS = Expressions.simplify(RHS; alpha_cache)
    end
    return :($LHS = $RHS)
end


function inst_to_expr(inst::Inst)

    ## factor this out if other ops with this property are added
    op = nameof(inst.op)
    dst = :(R[$(inst.dst)])
    src_t = inst.src < 0 ? :D : :R
    src_i = abs(inst.src)
    src = :($(src_t)[$(src_i)])
    # ad hoc check for boolean value
    if inst.op == xor && inst.src == inst.dst
        return :($dst = false)
    end
    if inst.arity == 2
        :($dst = $op($dst, $src))
    elseif inst.arity == 1
        :($dst = $op($src))
    else # inst.arity == 0
        :($dst = $(inst.op()))
    end
end


# TODO if we store effective_indices we don't need to store effective code
Base.@kwdef mutable struct Creature
    chromosome::Vector{Inst}
    effective_code::Union{Nothing,Vector{Inst}}
    effective_indices = nothing
    phenotype = nothing
    #fitness::Vector{Float64}
    fitness::Fitness
    name::String
    generation::Int
    num_offspring::Int = 0
    parents = []
    likeness = []
    performance = nothing
    symbolic = nothing
    native_island = myid() == 1 ? 1 : myid() - 1
end

function effective_code(g::Creature)
    if g.effective_indices === nothing
        g.effective_indices = get_effective_indices(g.chromosome, [1])
    end
    return g.chromosome[g.effective_indices]
end

function decompile(
    g::Creature;
    assign = true,
    incremental_simplify = true,
    simplify = !incremental_simplify,
    alpha_cache = true,
)
    if !isnothing(g.symbolic) && assign
        return g.symbolic
    end
    @debug "Decompiling $(g.name)'s chromosome..."
    symbolic = to_expr(
        g.chromosome,
        intron_free = true,
        incremental_simplify = incremental_simplify,
        alpha_cache = alpha_cache,
    )
    if simplify
        symbolic = Expressions.simplify(symbolic)
    end
    if assign
        g.symbolic = symbolic
    end
    return symbolic
end




function Creature(config::NamedTuple)
    len = rand(config.genotype.min_len:config.genotype.max_len)
    chromosome = [
        rand_inst(
            ops = config.genotype.ops,
            num_data = config.genotype.data_n,
            num_regs = config.genotype.registers_n,
        ) for _ = 1:len
    ]
    fitness = NewFitness()
    Creature(
        chromosome = chromosome,
        effective_code = nothing,
        phenotype = nothing,
        fitness = fitness,
        name = Names.rand_name(4),
        generation = 0,
    )
end


# For deserializing
function Creature(d::Dict)

    phenotype = if !(isnothing(d["phenotype"]))
        ph = d["phenotype"]
        results = ph["results"] |> BitArray
        trace = cat([cat(a..., dims = 2) for a in ph["trace"]]..., dims = 3) |> BitArray
        trace_info = Float64.(ph["trace_info"])
        trace_hamming =
            "trace_hamming" ∈ keys(ph) ? Float64.(ph["trace_hamming"]) : Float64[]
        (; results, trace, trace_info, trace_hamming)
    else
        nothing
    end

    Creature(
        chromosome = Inst.(d["chromosome"]),
        effective_code = isnothing(d["effective_code"]) ? nothing :
                         Inst.(d["effective_code"]),
        effective_indices = isnothing(d["effective_indices"]) ? nothing :
                            Vector{Int}(d["effective_indices"]),
        phenotype = phenotype,
        fitness = NewFitness(),
        name = d["name"],
        generation = d["generation"],
        num_offspring = d["num_offspring"],
        parents = d["parents"],
        likeness = d["likeness"],
        performance = d["performance"],
    )

end


Creature(s::String) = Creature(JSON.parse(s))


function serialize_creature(g::Creature)
    JSON.json(g)
end

function deserialize_creature(s::String)
    JSON.parse(s) |> Creature
end



function Creature(chromosome::Vector{Inst})
    Creature(
        chromosome = chromosome,
        effective_code = nothing,
        phenotype = nothing,
        fitness = NewFitness(),
        name = Names.rand_name(4),
        generation = 0,
    )
end


function crop(seq, len)
    length(seq) > len ? seq[1:len] : seq
end

# TODO run some experiments and see if this actually improves over random
# splice points
function splice_point(g, weighted_by_trace_info = true)
    if !weighted_by_trace_info || isnothing(g.phenotype)
        @show isnothing(g.phenotype)
        return rand(1:length(g.chromosome))
    end
    weights = Vector{Float64}(undef, length(g.chromosome))
    weights[g.effective_indices] .= g.phenotype.trace_info
    sample(1:length(g.chromosome), Weights(weights), 1) |> first
end

function crossover(mother::Creature, father::Creature; config = nothing)::Vector{Creature}
    mother.num_offspring += 1
    father.num_offspring += 1


    mx = splice_point(mother, config.genotype.weight_crossover_points)
    fx = splice_point(father, config.genotype.weight_crossover_points)
    chrom1 = [mother.chromosome[1:mx]; father.chromosome[(fx+1):end]]
    chrom2 = [father.chromosome[1:fx]; mother.chromosome[(mx+1):end]]
    len = config.genotype.max_len
    children = Creature.([crop(chrom1, len), crop(chrom2, len)])
    generation = max(mother.generation, father.generation) + 1
    for child in children
        child.parents = [mother.name, father.name]
        child.generation = generation
        child.fitness = NewFitness()
    end
    children
end


function mutate!(creature::Creature; config = nothing)
    inds = keys(creature.chromosome)
    i = rand(inds)
    creature.chromosome[i] = rand_inst(
        ops = config.genotype.ops,
        num_data = config.genotype.data_n,
        num_regs = config.genotype.registers_n,
    )
    return
end




# What if we define parsimony wrt the # of unnecessary instructions?

function _parsimony(g::Creature)
    len = length(g.chromosome)
    len == 0 ? -Inf : 1.0 / len
end


function effective_parsimony(g::Creature)
    if isnothing(g.effective_code)
        g.effective_indices = get_effective_indices(g.chromosome, [1])
        g.effective_code = g.chromosome[g.effective_indices]
    end
    length(g.effective_code) / length(g.chromosome)
end


function stepped_parsimony(g::Creature, threshold::Int)
    len = length(g.chromosome)
    if len == 0
        -Inf
    elseif len < threshold
        1.0
    else
        1.0 / len
    end
end


# try just _parsimony TODO
parsimony(g::Creature) = stepped_parsimony(g::Creature, 50)


ST_TRANS = [:& => "AND", :xor => "XOR", :| => "OR", :~ => "NOT"] |> Dict

function st_inst(inst::Inst)
    src = inst.src < 0 ? "D[$(abs(inst.src))]" : "R[$(inst.src)]"
    dst = "R[$(inst.dst)]"
    lhs = "$(dst) := "
    if inst.arity == 2
        op = ST_TRANS[nameof(inst.op)]
        rhs = "$(dst) $(op) $(src);"
    elseif inst.arity == 1
        op = ST_TRANS[nameof(inst.op)]
        rhs = "$(op) $(src);"
    else # inst.arity == 0
        op = string(inst.op()) |> uppercase
        rhs = "$(op);"
    end
    lhs * rhs
end

function structured_text(prog; config = nothing, comment = "")
    prog = strip_introns(prog, [1])
    num_regs = config.genotype.registers_n
    reg_decl = """
VAR
    R : ARRAY[1..$(num_regs)] OF BOOL;
END_VAR

"""
    body = "    " * join(map(st_inst, prog), "\n    ")
    out = "\n    Out := R[1];\n"

    payload = reg_decl * body * out

    inputsize = config.genotype.data_n
    st = StructuredTextTemplate.wrap(payload, inputsize)
    if length(comment) > 0
        return "(*\n$(comment)\n*)\n\n$(st)"
    else
        return st
    end
end

function evaluate(g::Creature; INPUT, config::NamedTuple, make_trace = true)
    if isnothing(g.effective_code)
        #g.effective_code = strip_introns(g.chromosome, [config.genotype.output_reg])
        g.effective_indices = get_effective_indices(g.chromosome,
                                                    config.genotype.output_reg)
        g.effective_code = g.chromosome[g.effective_indices]
    end
    execute_vec(
        g.effective_code,
        INPUT,
        config = config,
        make_trace = make_trace,
    )
end


end # end module
