using DrWatson
@quickactivate "project"

using DataFrames, CSV, Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(plotsdir())

required_files = [
    datadir("sir_det.csv"),
    datadir("sir_stoch.csv"),
    datadir("sir_scan.csv"),
]

for file in required_files
    if !isfile(file)
        error("Не найден файл $file. Сначала запустите sirpetri_run.jl и sirpetri_scan_parameters.jl")
    end
end

df_det = CSV.read(datadir("sir_det.csv"), DataFrame)
df_stoch = CSV.read(datadir("sir_stoch.csv"), DataFrame)
df_scan = CSV.read(datadir("sir_scan.csv"), DataFrame)

p1 = plot_infected_comparison(df_det, df_stoch)
savefig(p1, plotsdir("comparison.png"))

p2 = plot(
    df_scan.β,
    df_scan.peak_I,
    marker = :circle,
    xlabel = "β",
    ylabel = "Peak I",
    title = "Sensitivity of epidemic peak to β",
    linewidth = 2,
    label = "Peak I",
)
savefig(p2, plotsdir("sensitivity.png"))

println("Отчётные графики сохранены:")
println("  plots/comparison.png")
println("  plots/sensitivity.png")
