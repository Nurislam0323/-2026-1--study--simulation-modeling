using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots

include(srcdir("DESModels.jl"))

p = DESModels.MMcParams(; lambda = 0.9, mu = 0.5, servers = 2, customers = 1000, seed = 123)

events = DESModels.simulate_mmc(p)
summary = DESModels.summarize_mmc(events, p)

CSV.write(datadir("mmc_events.csv"), events)
CSV.write(datadir("mmc_summary.csv"), summary)
summary

plt_wait = plot(
    events.id,
    events.waiting_time,
    xlabel = "Customer",
    ylabel = "Waiting time",
    label = "Wq",
    title = "M/M/c waiting time",
    linewidth = 1.5,
)
savefig(plt_wait, plotsdir("mmc_waiting_time.png"))
plt_wait

plt_queue = plot(
    events.arrival_time,
    events.queue_length,
    xlabel = "Time",
    ylabel = "Queue length",
    label = "queue",
    title = "M/M/c queue length before arrivals",
    linewidth = 1.5,
)
savefig(plt_queue, plotsdir("mmc_queue_load.png"))
plt_queue
