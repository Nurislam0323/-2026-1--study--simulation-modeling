using DrWatson
@quickactivate "project"

using DataFrames, CSV, Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(datadir())
mkpath(plotsdir())

β_range = 0.1:0.05:0.8
γ_fixed = 0.1
tmax = 100.0

println("="^60)
println("Сканирование коэффициента заражения β")
println("="^60)

results = NamedTuple[]

for β in β_range
    net, u0, _ = build_sir_network(β, γ_fixed)
    df = simulate_deterministic(
        net,
        u0,
        (0.0, tmax);
        saveat = 0.5,
        rates = [β, γ_fixed],
    )

    peak_I = maximum(df.I)
    final_R = df.R[end]
    peak_time = df.time[argmax(df.I)]
    attack_rate = final_R / sum(u0)
    R0 = reproduction_number(β, γ_fixed)

    push!(
        results,
        (β = β, R0 = R0, peak_I = peak_I, peak_time = peak_time, final_R = final_R, attack_rate = attack_rate),
    )
    println("β = $(round(β, digits = 3)), R0 = $(round(R0, digits = 2)), peak_I = $(round(peak_I, digits = 2))")
end

df_scan = DataFrame(results)
CSV.write(datadir("sir_scan.csv"), df_scan)

p = plot_scan(df_scan)
savefig(p, plotsdir("sir_scan.png"))

println("Сканирование завершено:")
println("  data/sir_scan.csv")
println("  plots/sir_scan.png")
