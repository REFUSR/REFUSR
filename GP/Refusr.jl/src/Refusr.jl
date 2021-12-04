include("base.jl")
include("Dashboard.jl")

using Distributed
__precompile__(false) # Precompilation is causing the system to OOM!

#Base.Experimental.@optlevel 3

@show CORES = "REFUSR_PROCS" ∈ keys(ENV) ? parse(Int, ENV["REFUSR_PROCS"]) : 1

EXEFLAGS = "--project=$(Base.active_project())"

if CORES > nprocs()
    addprocs(CORES, topology = :master_worker, exeflags = EXEFLAGS)
end


@everywhere begin
    @info "Preparing environment on core $(myid()) of $(nprocs())..."
    if myid() != 1
        include("$(@__DIR__)/base.jl")
    end
    @info "Environment ready on core $(myid())."
end



function launch(config_path)
    config = prep_config(config_path)
    logger = Cockatrice.Logging.Logger(LOGGERS, config)

    headless = "REFUSR_HEADLESS" ∈ keys(ENV) && parse(Bool, ENV["REFUSR_HEADLESS"])

    server_task = if (!headless) && config.dashboard.enable
        try
            task = Dashboard.initialize_server(config = config, background = true)
            println("Waiting for server...")
            while !Dashboard.check_server(config)
                sleep(1)
                print(".")
            end
            println()
            log_dir = Dashboard.sanitize_log_dir(config.logging.dir)
            run(
                `xdg-open "http://$(config.dashboard.server):$(config.dashboard.port)/$(log_dir)"`,
            )
            task
        catch e
            @async begin nothing end
        end
    else
        @async begin
            nothing
        end
    end

    fitness_function = config.selection.fitness_function

    WORKERS = workers()

    # it would be nice to have an explicit single-thread option here.

    params = [
        :config => config,
        :fitness => fitness_function,
        :creature_type => LinearGenotype.Creature,
        :crossover => LinearGenotype.crossover,
        :mutate => LinearGenotype.mutate!,
        :tracers => TRACERS,
        :loggers => LOGGERS,
        :stopping_condition => stopping_condition,
        :objective_performance => objective_performance,
        :WORKERS => WORKERS,
        :callback =>
            L -> begin
                @info "[$(L.table.iteration_mean[end])] mean performance: $(L.table.objective_meanfinite[end])\t best performance: $(L.table.objective_maximum[end])"
            end,
        :LOGGER => logger,
    ]
    # TODO: rename some of these logger vars
    started_at = now()
    world, logger = Cosmos.run(; params...)
    finished_at = now()
    @info "Time spent in main GP loop, including initialization: $(finished_at - started_at)"
    #Distributed.rmprocs(WORKERS...)
    if CORES > 1
        try
            Distributed.rmprocs(WORKERS...)
        catch er
            @warn "Failed to remove worker processes: $(er)"
        end
    end
    elites = [w.elites[1] for w in world]
    champion = sort(elites, by = objective_performance)[end]
    push!(logger.specimens, champion)
    @info "Sending data on champion to dashboard" Dashboard.check_server(config)
    Cockatrice.Logging.dump_logger(logger)
    #Dashboard.ui_callback(logger) #, champion_md)
    # might as well decompile the specimens while we're waiting.
    # @async begin
    #     @info "Asynchronously decompiling specimens. Beware of race conditions..."
    #     for i in eachindex(logger.specimens)
    #         s = LinearGenotype.decompile(logger.specimens[i])
    #         @info "[$(i)/$(length(logger.specimens))] Decompiled $(logger.specimens[i].name)" s
    #     end
    # end
    wait(server_task)
    return (world = world, logger = logger, champion = champion)
end


# TODO:
# replace the very stupid L.dump slurper with some seek and read functions
# that look only at
# - the most recent rows of the csv
# - the most recent IM files
# - the most recent json specimen dumps

# have the logger dump the most recent specimens to json files in a subdir
