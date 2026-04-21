using DrWatson
@quickactivate "project"

using Random
using DataFrames, CSV, Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

β = 0.3
γ = 0.1
tmax = 100.0

R0 = reproduction_number(β, γ)
println("R0 = ", R0)

net, u0, states = build_sir_network(β, γ)
println(Dict(zip(states, u0)))

df_det = simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

p_det = plot_sir(df_det; title = "Deterministic SIR Petri net")
savefig(p_det, plotsdir("sir_det_dynamics.png"))
p_det

Random.seed!(123)
df_stoch = simulate_stochastic(net, u0, (0.0, tmax); rates = [β, γ])
CSV.write(datadir("sir_stoch.csv"), df_stoch)

p_stoch = plot_sir(df_stoch; title = "Stochastic SIR Petri net")
savefig(p_stoch, plotsdir("sir_stoch_dynamics.png"))
p_stoch

println("Детерминированный пик I: ", maximum(df_det.I))
println("Стохастический пик I: ", maximum(df_stoch.I))
