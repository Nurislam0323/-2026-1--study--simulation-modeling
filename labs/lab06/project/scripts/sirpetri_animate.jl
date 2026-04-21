using DrWatson
@quickactivate "project"

using Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(plotsdir())

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, _ = build_sir_network(β, γ)
df = simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.5, rates = [β, γ])

frame_step = max(1, floor(Int, size(df, 1) / 120))
df_frames = df[1:frame_step:end, :]

anim = @animate for row in eachrow(df_frames)
    bar(
        ["S", "I", "R"],
        [row.S, row.I, row.R],
        ylim = (0, sum(u0)),
        legend = false,
        xlabel = "State",
        ylabel = "Population",
        title = "SIR Petri net, t = $(round(row.time, digits = 1))",
        color = [:steelblue, :tomato, :seagreen],
    )
end

gif(anim, plotsdir("sir_animation.gif"), fps = 12)
println("Анимация сохранена в plots/sir_animation.gif")
