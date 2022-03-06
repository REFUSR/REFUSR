# Tests for the VM

include("../src/RandomFunctions.jl")


function test_intron_stripping()
    config = (
        genotype = (
            registers_n = 10,
            data_n = 10,
            max_steps = 1024,
            output_reg = [1,2],
            ops = Symbol.(split("& | mov ~")),
        ),
    )
    @showprogress for i in 1:10000
        code = LinearGenotype.random_program(128; ops = config.genotype.ops, num_regs = config.genotype.registers_n, num_data = config.genotype.data_n)
        eff = code[LinearGenotype.get_effective_indices(code, config.genotype.output_reg)]
        data = rand(Bool, config.genotype.data_n)
        r1,_ = LinearGenotype.execute(code, data; config, make_trace=false)
        r2,_ = LinearGenotype.execute(eff, data; config, make_trace=false)
        @test r1 == r2
    end
end

function machine_tests()
    @info "Beginning machine tests"
    test_intron_stripping()
end
