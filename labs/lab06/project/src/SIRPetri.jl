module SIRPetri

using AlgebraicPetri
using Catlab.Graphics
using OrdinaryDiffEq
using Plots
using DataFrames
using Random

export build_sir_network, sir_ode, simulate_deterministic, simulate_stochastic
export plot_sir, plot_scan, plot_infected_comparison, to_graphviz_sir
export reproduction_number, epidemic_threshold

"""
    build_sir_network(β=0.3, γ=0.1; S0=990.0, I0=10.0, R0=0.0)

Создаёт размеченную сеть Петри для модели SIR.

Переходы:
- `infection`: S + I -> I + I
- `recovery`: I -> R

Возвращает `(net, u0, states)`.
"""
function build_sir_network(β = 0.3, γ = 0.1; S0 = 990.0, I0 = 10.0, R0 = 0.0)
    states = [:S, :I, :R]
    net = LabelledPetriNet(
        states,
        :infection => ([:S, :I] => [:I, :I]),
        :recovery => ([:I] => [:R]),
    )
    u0 = Float64[S0, I0, R0]
    return net, u0, states
end

reproduction_number(β, γ) = β / γ
epidemic_threshold(γ) = γ

function infection_propensity(S, I, R, β; normalized = true)
    N = S + I + R
    if N <= 0
        return 0.0
    end
    return normalized ? β * S * I / N : β * S * I
end

"""
    sir_ode(net, rates=[0.3, 0.1]; normalized=true)

Возвращает правую часть ОДУ для SIR-сети Петри.
По умолчанию используется частотная нормировка `β*S*I/N`, чтобы `R0 = β/γ`.
"""
function sir_ode(net, rates = [0.3, 0.1]; normalized = true)
    function f!(du, u, p, t)
        S, I, R = u
        β, γ = rates

        infection_rate = infection_propensity(S, I, R, β; normalized)
        recovery_rate = γ * I

        du[1] = -infection_rate
        du[2] = infection_rate - recovery_rate
        du[3] = recovery_rate
        return nothing
    end
    return f!
end

"""
    simulate_deterministic(net, u0, tspan; saveat=0.1, rates=[0.3, 0.1], normalized=true)

Выполняет детерминированную ODE-симуляцию и возвращает DataFrame
с колонками `time`, `S`, `I`, `R`.
"""
function simulate_deterministic(
    net,
    u0,
    tspan;
    saveat = 0.1,
    rates = [0.3, 0.1],
    normalized = true,
)
    f = sir_ode(net, rates; normalized)
    prob = ODEProblem(f, u0, tspan)
    sol = solve(prob, Tsit5(), saveat = saveat)

    return DataFrame(
        time = sol.t,
        S = sol[1, :],
        I = sol[2, :],
        R = sol[3, :],
    )
end

"""
    simulate_stochastic(net, u0, tspan; rates=[0.3, 0.1], rng=Random.GLOBAL_RNG, normalized=true)

Выполняет стохастическую симуляцию прямым алгоритмом Гиллеспи.
Возвращает DataFrame с нерегулярными временными точками и маркировками сети.
"""
function simulate_stochastic(
    net,
    u0,
    tspan;
    rates = [0.3, 0.1],
    rng = Random.GLOBAL_RNG,
    normalized = true,
)
    u = Float64.(copy(u0))
    t = first(tspan)
    tmax = last(tspan)
    β, γ = rates

    times = Float64[t]
    states = Vector{Float64}[copy(u)]

    while t < tmax
        S, I, R = u
        a_inf = infection_propensity(S, I, R, β; normalized)
        a_rec = γ * I
        a0 = a_inf + a_rec

        if a0 <= 0
            break
        end

        dt = -log(rand(rng)) / a0
        event_selector = rand(rng) * a0

        if event_selector < a_inf && u[1] >= 1
            u[1] -= 1
            u[2] += 1
        elseif u[2] >= 1
            u[2] -= 1
            u[3] += 1
        else
            break
        end

        t += dt
        if t <= tmax
            push!(times, t)
            push!(states, copy(u))
        end
    end

    return DataFrame(
        time = times,
        S = [s[1] for s in states],
        I = [s[2] for s in states],
        R = [s[3] for s in states],
    )
end

"""
    plot_sir(df; title="SIR dynamics")

Строит стандартный график динамики S, I, R.
"""
function plot_sir(df; title = "SIR dynamics")
    return plot(
        df.time,
        Matrix(df[:, [:S, :I, :R]]),
        label = ["S (Susceptible)" "I (Infected)" "R (Recovered)"],
        xlabel = "Time",
        ylabel = "Population",
        title = title,
        linewidth = 2,
    )
end

function plot_scan(df_scan)
    return plot(
        df_scan.β,
        Matrix(df_scan[:, [:peak_I, :final_R]]),
        label = ["Peak I" "Final R"],
        marker = :circle,
        xlabel = "β (infection rate)",
        ylabel = "Population",
        title = "Sensitivity to β",
        linewidth = 2,
    )
end

function plot_infected_comparison(df_det, df_stoch)
    p = plot(
        df_det.time,
        df_det.I,
        label = "Deterministic I",
        xlabel = "Time",
        ylabel = "Infected",
        title = "Deterministic vs stochastic SIR",
        linewidth = 2,
    )
    plot!(p, df_stoch.time, df_stoch.I, label = "Stochastic I", linewidth = 2, alpha = 0.8)
    return p
end

"""
    to_graphviz_sir(net)

Возвращает Graphviz-представление сети Петри.
"""
function to_graphviz_sir(net)
    return to_graphviz(net, prog = "dot")
end

end # module
