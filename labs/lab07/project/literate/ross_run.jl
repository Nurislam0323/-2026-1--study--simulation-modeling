using DrWatson
@quickactivate "project"

using CSV
using Plots

include(srcdir("DESModels.jl"))

p = DESModels.RossParams(; machines = 10, spares = 3, repairers = 1, runs = 200, seed = 150)

results, path = DESModels.simulate_ross(p)
summary = DESModels.summarize_ross(results, p)
path_metrics = DESModels.ross_path_metrics(path, p)

CSV.write(datadir("ross_runs.csv"), results)
CSV.write(datadir("ross_path.csv"), path)
CSV.write(datadir("ross_summary.csv"), summary)
CSV.write(datadir("ross_path_metrics.csv"), path_metrics)
summary

plt_path = plot(
    path.time,
    path.good_machines,
    xlabel = "Time",
    ylabel = "Good machines",
    label = "good machines",
    title = "Ross model: first simulated path",
    linewidth = 2,
    seriestype = :steppost,
)
savefig(plt_path, plotsdir("ross_good_machines.png"))
plt_path

plt_queue = plot(
    path.time,
    path.repair_queue,
    xlabel = "Time",
    ylabel = "Repair queue length",
    label = "repair queue",
    title = "Ross model: repair queue",
    linewidth = 2,
    seriestype = :steppost,
)
savefig(plt_queue, plotsdir("ross_repair_queue.png"))
plt_queue

plt_hist = histogram(
    results.crash_time,
    bins = 25,
    xlabel = "Crash time",
    ylabel = "Frequency",
    label = "simulation",
    title = "Ross model: crash time distribution",
)
vline!(plt_hist, [summary.analytic_crash_time[1]], label = "analytic mean", linewidth = 2)
savefig(plt_hist, plotsdir("ross_crash_time_histogram.png"))
plt_hist
