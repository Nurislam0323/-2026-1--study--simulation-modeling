using DrWatson
@quickactivate "project"

using Random
using DataFrames, CSV, Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(datadir())
mkpath(plotsdir())

β = 0.3
γ = 0.1
tmax = 100.0

println("="^60)
println("Лабораторная работа №6: базовый прогон SIR-сети Петри")
println("="^60)
println("β = $β")
println("γ = $γ")
println("R0 = $(round(reproduction_number(β, γ), digits = 3))")
println("tmax = $tmax")

net, u0, states = build_sir_network(β, γ)
println("Начальная маркировка: ", Dict(zip(states, u0)))

df_det = simulate_deterministic(net, u0, (0.0, tmax), saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

Random.seed!(123)
df_stoch = simulate_stochastic(net, u0, (0.0, tmax), rates = [β, γ])
CSV.write(datadir("sir_stoch.csv"), df_stoch)

p_det = plot_sir(df_det; title = "Deterministic SIR Petri net")
savefig(p_det, plotsdir("sir_det_dynamics.png"))

p_stoch = plot_sir(df_stoch; title = "Stochastic SIR Petri net")
savefig(p_stoch, plotsdir("sir_stoch_dynamics.png"))

println("Детерминированный пик I: ", round(maximum(df_det.I), digits = 2))
println("Стохастический пик I: ", round(maximum(df_stoch.I), digits = 2))
println("Результаты сохранены:")
println("  data/sir_det.csv")
println("  data/sir_stoch.csv")
println("  plots/sir_det_dynamics.png")
println("  plots/sir_stoch_dynamics.png")
