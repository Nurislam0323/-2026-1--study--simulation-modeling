module DESModels

using DataFrames
using Distributions
using LinearAlgebra
using Statistics
using StableRNGs

export MMcParams,
       RossParams,
       mmc_theory,
       simulate_mmc,
       summarize_mmc,
       simulate_ross_once,
       simulate_ross,
       ross_expected_crash_time,
       ross_path_metrics,
       summarize_ross,
       scan_ross_parameters

Base.@kwdef struct MMcParams
    lambda::Float64 = 0.9
    mu::Float64 = 0.5
    servers::Int = 2
    customers::Int = 1000
    seed::Int = 123
end

Base.@kwdef struct RossParams
    machines::Int = 10
    spares::Int = 3
    repairers::Int = 1
    failure_rate::Float64 = 0.01
    repair_rate::Float64 = 1.0
    runs::Int = 100
    seed::Int = 150
end

function mmc_theory(p::MMcParams)
    c = p.servers
    lambda = p.lambda
    mu = p.mu
    rho = lambda / (c * mu)
    rho < 1 || error("M/M/c stationary mode requires rho < 1")

    a = lambda / mu
    left = sum(a^n / factorial(n) for n in 0:(c - 1))
    right = a^c / (factorial(c) * (1 - rho))
    p0 = inv(left + right)
    p_wait = right * p0
    lq = p_wait * rho / (1 - rho)
    wq = lq / lambda
    w = wq + inv(mu)
    l = lambda * w

    return (; rho, p0, p_wait, lq, wq, w, l)
end

function simulate_mmc(p::MMcParams)
    rng = StableRNG(p.seed)
    arrival_dist = Exponential(1 / p.lambda)
    service_dist = Exponential(1 / p.mu)

    server_available = zeros(Float64, p.servers)
    arrival_time = 0.0
    rows = NamedTuple[]
    departures = Float64[]

    for id in 1:p.customers
        arrival_time += rand(rng, arrival_dist)
        service_time = rand(rng, service_dist)
        server_id = argmin(server_available)
        service_start = max(arrival_time, server_available[server_id])
        departure_time = service_start + service_time
        waiting_time = service_start - arrival_time
        in_system = count(t -> t > arrival_time, departures)
        queue_length = max(0, in_system - p.servers)

        server_available[server_id] = departure_time
        push!(departures, departure_time)

        push!(rows, (;
            id,
            arrival_time,
            service_start,
            departure_time,
            service_time,
            waiting_time,
            system_time = departure_time - arrival_time,
            server_id,
            queue_length,
        ))
    end

    return DataFrame(rows)
end

function summarize_mmc(events::DataFrame, p::MMcParams)
    total_time = maximum(events.departure_time)
    busy_time = sum(events.service_time)
    theory = mmc_theory(p)

    return DataFrame([(
        lambda = p.lambda,
        mu = p.mu,
        servers = p.servers,
        customers = p.customers,
        rho = theory.rho,
        mean_waiting_time = mean(events.waiting_time),
        theoretical_wq = theory.wq,
        mean_system_time = mean(events.system_time),
        theoretical_w = theory.w,
        mean_queue_length = mean(events.queue_length),
        theoretical_lq = theory.lq,
        utilization = busy_time / (p.servers * total_time),
        probability_wait = mean(events.waiting_time .> 0),
        theoretical_p_wait = theory.p_wait,
    )])
end

function simulate_ross_once(p::RossParams, rng::StableRNG; keep_path::Bool = true)
    good = p.machines + p.spares
    time = 0.0
    path = NamedTuple[(;
        time,
        good_machines = good,
        broken_machines = 0,
        active_repairs = 0,
        repair_queue = 0,
        event = "start",
    )]

    while good >= p.machines
        working = min(p.machines, good)
        broken = p.machines + p.spares - good
        failure_intensity = working * p.failure_rate
        repair_intensity = min(p.repairers, broken) * p.repair_rate
        total_intensity = failure_intensity + repair_intensity

        dt = rand(rng, Exponential(1 / total_intensity))
        time += dt

        if rand(rng) < failure_intensity / total_intensity
            good -= 1
            event = good < p.machines ? "crash" : "failure"
        else
            good += 1
            event = "repair"
        end

        if keep_path
            push!(path, (;
                time,
                good_machines = good,
                broken_machines = p.machines + p.spares - good,
                active_repairs = min(p.repairers, p.machines + p.spares - good),
                repair_queue = max(0, p.machines + p.spares - good - p.repairers),
                event,
            ))
        end
    end

    return time, DataFrame(path)
end

function simulate_ross(p::RossParams)
    rng = StableRNG(p.seed)
    results = NamedTuple[]
    first_path = DataFrame()

    for run in 1:p.runs
        crash_time, path = simulate_ross_once(p, rng; keep_path = run == 1)
        push!(results, (;
            run,
            machines = p.machines,
            spares = p.spares,
            repairers = p.repairers,
            crash_time,
        ))
        if run == 1
            first_path = path
        end
    end

    return DataFrame(results), first_path
end

function ross_expected_crash_time(p::RossParams)
    states = collect(p.machines:(p.machines + p.spares))
    n = length(states)
    index = Dict(state => i for (i, state) in enumerate(states))
    A = zeros(Float64, n, n)
    b = ones(Float64, n)

    for state in states
        row = index[state]
        working = min(p.machines, state)
        broken = p.machines + p.spares - state
        failure_intensity = working * p.failure_rate
        repair_intensity = min(p.repairers, broken) * p.repair_rate
        total_intensity = failure_intensity + repair_intensity

        A[row, row] = total_intensity
        if state > p.machines
            A[row, index[state - 1]] -= failure_intensity
        end
        if state < p.machines + p.spares
            A[row, index[state + 1]] -= repair_intensity
        end
    end

    solution = A \ b
    return solution[index[p.machines + p.spares]]
end

function ross_path_metrics(path::DataFrame, p::RossParams)
    if nrow(path) < 2
        return DataFrame([(
            repairer_utilization = 0.0,
            average_repair_queue = 0.0,
            observed_time = 0.0,
        )])
    end

    total_time = last(path.time)
    intervals = diff(path.time)
    active_repairs = path.active_repairs[1:end-1]
    repair_queue = path.repair_queue[1:end-1]

    return DataFrame([(
        repairer_utilization = sum(active_repairs .* intervals) / (p.repairers * total_time),
        average_repair_queue = sum(repair_queue .* intervals) / total_time,
        observed_time = total_time,
    )])
end

function summarize_ross(results::DataFrame, p::RossParams)
    analytic = ross_expected_crash_time(p)
    return DataFrame([(
        machines = p.machines,
        spares = p.spares,
        repairers = p.repairers,
        runs = p.runs,
        mean_crash_time = mean(results.crash_time),
        std_crash_time = std(results.crash_time),
        min_crash_time = minimum(results.crash_time),
        max_crash_time = maximum(results.crash_time),
        analytic_crash_time = analytic,
        relative_error = abs(mean(results.crash_time) - analytic) / analytic,
    )])
end

function scan_ross_parameters(; machines_values = [6, 8, 10, 12],
                              spares_values = [1, 2, 3, 5],
                              repairers_values = [1, 2],
                              runs = 100,
                              seed = 150)
    rows = NamedTuple[]
    current_seed = seed

    for machines in machines_values, spares in spares_values, repairers in repairers_values
        p = RossParams(; machines, spares, repairers, runs, seed = current_seed)
        results, _ = simulate_ross(p)
        summary = summarize_ross(results, p)
        push!(rows, NamedTuple(summary[1, :]))
        current_seed += 1
    end

    return DataFrame(rows)
end

end
