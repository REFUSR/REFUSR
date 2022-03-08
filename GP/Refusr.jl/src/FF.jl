module FF

using AxisArrays
using FunctionWrappers: FunctionWrapper
using Statistics, CSV, DataFrames, InformationMeasures
using StatsBase: sample
using Setfield
using ..BitEntropy
using ..Sensitivity
using ..LinearGenotype
using Cockatrice.Geo



const Fitness = LinearGenotype.Fitness
const NewFitness = LinearGenotype.NewFitness
const parsimony = LinearGenotype.parsimony
const evaluate = LinearGenotype.evaluate
###

DATA = nothing
## FIXME the ORACLE function doesn't work for multiple outputs, and, more seriously
## neither does the boolean dirichlet energy function, but the latter *could* be adapted
## to handle functions f: B --> Z (after mapping n-bit Boolean outputs to integers)
ORACLE = nothing
SEQNO = nothing
INPUT = nothing
TARGET_ENERGY = nothing
ANSWERS = nothing

get_answers() = ANSWERS

oracle(row) = ORACLE[row]
seqno(row) = SEQNO[row]

function graydecode(n::Integer)
    r = n
    while (n >>= 1) != 0
        r ⊻= n
    end
    return r
end

grayencode(n::Integer) = n ⊻ (n >> 1)

pack(row) = sum([row[i] << (i - 1) for i = 1:length(row)])

graydecode_row(row) = pack(row) |> graydecode


function data_io_count(data)
    cols = ncol(data)
    outs = count(x -> startswith(x, "OUT"), names(data))
    (cols - outs, outs)
end


function _set_data(data::String; samplesize = :ALL)
    global DATA, INPUT, ORACLE, SEQNO, TARGET_ENERGY, ANSWERS
    data = Bool.(CSV.read(data, DataFrame))
    data = sort(eachrow(data), by = r -> graydecode_row(r[1:end-1])) |> DataFrame
    if samplesize === :ALL || DataFrames.nrow(data) <= samplesize
        DATA = data
    else
        rows = sample(1:size(data, 1), samplesize, replace = false)
        DATA = data[rows, :]
    end

    cols = ncol(data)
    outs = count(x -> startswith(x, "OUT"), names(data))
    ins = cols - outs

    INPUT = Array{Bool}(DATA[:, 1:ins]) |> BitArray
    ANSWERS = DATA[!, ins+1:end] |> Array |> transpose |> BitArray #DATA.OUT
    ORACLE = Dict{BitVector, Bool}()
    SEQNO = Dict{BitVector, Integer}()
    for (i, row) in eachrow(INPUT) |> enumerate
        ORACLE[row] = Bool(DATA[i,end])
        SEQNO[row] = i
    end
    #TARGET_ENERGY = Sensitivity.dirichlet_energy(x -> ORACLE[x], size(INPUT, 2))
end


hamming(a, b) = (!).(a .⊻ b)

mutualinfo(a, b) = get_mutual_information(a, b) / get_entropy(a)


get_difficulty_scores(IM) = map(x -> 1.0 - mean(x), eachslice(IM, dims=2))

function get_hamming(answers, result; IM = nothing, sharing = (!isnothing(IM)))
    correct = map(mean, eachcol((!).(answers .⊻ result))) # let's reward partial success
    if sharing
        adjusted = correct .* get_difficulty_scores(IM)
        mean(adjusted)
    else
        mean(correct)
    end
end

unzip(a) = map(x -> getfield.(a, x), fieldnames(eltype(a)))


FASTMODE = false

function dirichlet_energy_of_results(results, config)
    if config.selection.fitness_weights.dirichlet == 0
        # why bother?
        return 0
    end
    f(v) = results[seqno(v)]
    if FASTMODE
        Sensitivity.fast_dirichlet_energy(f, config.genotype.data_n,
                                          target=TARGET_ENERGY,
                                          initial_sample=0.05,
                                          epsilon=0.05)
    else
        Sensitivity.dirichlet_energy(f, config.genotype.data_n)
    end
end


function dirichlet_energy_of_genotype(g, config)
    if g.phenotype !== nothing
        return dirichlet_energy_of_phenotype(g.phenotype, config)
    end
    code = LinearGenotype.effective_code(g)
    f = LinearGenotype.compile_chromosome(code, config=config)
    Sensitivity.dirichlet_energy(f, config.genotype.data_n)
end





# Only defined for Linear Genotypes for now
# returns a 2d array of intermediate results
intermediate_results(trace) = vcat([transpose(tr[reg = 1]) for tr in trace]...)

intermediate_hamming(answers, trace) =
    map(c -> get_hamming(answers, c), eachcol(intermediate_results(trace)))



# to keep things working smoothly, we'll consider an absent phenotype to have passed
# all tests, just for the sake of difficulty calculation. The idea here is that a
# virgin interaction matrix shouldn't alter the hamming score at all -- which is what
# will happen when the score is multiplied by 1.
# FIXME try rand() instead of ones(), so that it alters it in an "expected" or "average"
# way, instead.

random_results() = BitArray(rand(Bool, size(ANSWERS)...))

passes(e) =
    isnothing(e.phenotype) ? random_results() : (~).(e.phenotype.results .⊻ ANSWERS)

## TODO maintain this as a field of the Geo object, and update it in a piecemeal
## way, as needed. No need to reevaluate every row, every step.
function build_interaction_matrix(geo)
    dims = length(size(ANSWERS)) + 1
    if !isnothing(geo.interaction_matrix)
        geo.interaction_matrix
    else
        im = cat(passes.(reshape(geo.deme, prod(size(geo.deme))))...; dims)
        geo.interaction_matrix = AxisArray(im, :correct, :problem, :creature)
    end
end

# Some trace accessors for convenience. Check to make sure these aren't obsolete.

function trace_accessor(trace; reg = :, step = :, case = :)
    trace[reg, step, case]
end


function add_data_to_trace(trace, input = INPUT)
    n_steps = size(trace, 2)
    x = repeat(INPUT, 1, 1, n_steps)
    p = permutedims(x, [2, 3, 1])
    cat(p, trace, dims = (1,))
end


## See Krawiec, chapter 6
function trace_consistency(trace, answers)
    A = map(r -> BitEntropy.conditional_entropy(answers, r), eachslice(trace, dims = 2))
    B = map(r -> BitEntropy.conditional_entropy(r, answers), eachslice(trace, dims = 2))
    minimum(A .+ B)
end


OUTREG = 1

function trace_hamming(trace, answers)
    x = view(trace, OUTREG, :, :) .⊻ answers
    (1.0 .- map(mean, eachcol(x))) |> maximum
end


function trace_information(trace; answers = ANSWERS)
    x = view(trace, OUTREG, :, :)
    map(x -> mutualinfo(answers, x), eachcol(x))
end


function active_trace_information(;
    code,
    trace,
    answers = ANSWERS,
    measure = mutualinfo,
)
    slices = (view(trace, r, :, n) for (n, r) in enumerate(i.dst for i in code))
    [measure(answers[1,:], s) for s in slices] # KLUDGE
    # Not really sure how best to adapt this particular function to multiple outputs
end


## NOTE on translating coordinates:
# A[(i[2]-1)*(size(A,1))+i[1]] == A[i...]

function update_interaction_matrix!(geo, index, out_vec)
    if geo.interaction_matrix === nothing
        geo.interaction_matrix = build_interaction_matrix(geo)
    end
    flat_index = Geo.hilbert_index(geo, index)
    geo.interaction_matrix[creature=flat_index] = (!).(out_vec .⊻ ANSWERS)
end


function get_difficulty(interaction_matrix, row_index)
    interaction_matrix[row_index, :] |> mean
end

## FIXME: phenotypes are disappearing! why?!
## This will take some debugging.
function fit(geo, i)
    global DATA
    g = geo.deme[i]
    config = geo.config
    if DATA === nothing
        _set_data(config.selection.data)
    end

    if isnothing(g.effective_code)
        g.effective_indices = LinearGenotype.get_effective_indices(g.chromosome, [1])
        g.effective_code = view(g.chromosome, g.effective_indices)
    end

    if isempty(g.effective_code)
        return NewFitness()
    end

    interaction_matrix = build_interaction_matrix(geo)

    answers = ANSWERS

    res, tr = evaluate(g, config = config, INPUT = INPUT, make_trace = true)
    hamming(a, b) = (~).(a .⊻ b) |> mean
    g.phenotype = (
        results = res,
        trace = tr,
        trace_info = active_trace_information(
                trace = tr,
                code = g.effective_code,
                measure = mutualinfo,
            ),
        trace_hamming = active_trace_information(
                trace = tr,
                code = g.effective_code,
                measure = hamming,
            ),
        dirichlet_energy = 0, ## KLUDGE
    )

    # since we don't have limitless confidence in any one
    # fitness metric, and would like to make room for tie-
    # breakers, we'll round off the various attributes
    # after a certain number of digits.
    # Only relative ingenuity needs to be reevaluated
    H = if config.selection.fitness_weights.ingenuity > 0
        get_hamming(
            answers,
            g.phenotype.results,
            sharing = config.selection.fitness_sharing,
            IM = interaction_matrix,
        )
    else
        0
    end
    update_interaction_matrix!(geo, i, g.phenotype.results)

    D = dirichlet_energy = g.phenotype.dirichlet_energy

    I = if g.fitness.information |> isfinite
        g.fitness.information
    else
        maximum(g.phenotype.trace_info)
    end

    P = if g.fitness.parsimony |> isfinite
        g.fitness.parsimony
    else
        parsimony(g)
    end

    _fitness = (dirichlet = D, ingenuity = H, information = I, parsimony = P)
    weights = config.selection.fitness_weights
    scalar = scalar_fitness(_fitness, weights)
    g.fitness = (scalar = scalar, _fitness...)
    return g.fitness
end


function scalar_fitness(fitness::NamedTuple, weights::NamedTuple)
    sum(fitness[k] * weights[k] for k in keys(weights))
end

function scalar_fitness(g::LinearGenotype.Creature, config)
    scalar_fitness(g.fitness, config.selection.fitness_weights)
end


## TODO: the names of each fitness attribute should be paired with the actual
## functions, and they should be selectable from the config file, as they were
## in berbalang

## TODO
# partial evaluation:
# - evaluate random subexpressions and measure mutual information to goal,
#   to incentivize partial solutions.

end # end module FF

# TODO: Implement Trace Consistency fitness metric
