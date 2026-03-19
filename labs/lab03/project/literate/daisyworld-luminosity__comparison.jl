using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
include(srcdir("daisyworld.jl"))
using CairoMakie

black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]
temperature(model) = StatsBase.mean(model.temperature)
mdata = [temperature, :solar_luminosity]

param_list = [
    (max_age = 25, init_white = 0.2, init_black = 0.2),
    (max_age = 40, init_white = 0.2, init_black = 0.2),
    (max_age = 25, init_white = 0.8, init_black = 0.2),
    (max_age = 40, init_white = 0.8, init_black = 0.2),
]

results = []
for (i, params) in enumerate(param_list)
    model = daisyworld(; 
        griddims = (30, 30),
        albedo_white = 0.75,
        albedo_black = 0.25,
        surface_albedo = 0.4,
        solar_change = 0.005,
        solar_luminosity = 1.0,
        scenario = :ramp,
        seed = 165,
        params...
    )
    agent_df, model_df = run!(model, 1000; adata = adata, mdata = mdata)
    push!(results, (params = params, agent_df = agent_df, model_df = model_df, idx = i))
end

figure = CairoMakie.Figure(size = (900, 700))

ax1 = Axis(figure[1, 1], 
    ylabel = "daisy count",
    title = "Численность маргариток")

ax2 = Axis(figure[2, 1], 
    ylabel = "temperature",
    title = "Средняя температура")

ax3 = Axis(figure[3, 1], 
    xlabel = "tick", 
    ylabel = "luminosity",
    title = "Солнечная светимость")

colors = [:blue, :green, :orange, :red]

for (i, result) in enumerate(results)
    params = result.params
    agent_df = result.agent_df
    model_df = result.model_df
    label = "max_age=$(params.max_age), w=$(params.init_white)"
    
    # Численность (сумма чёрных и белых)
    total_count = agent_df[!, :count_black] .+ agent_df[!, :count_white]
    lines!(ax1, agent_df[!, :time], total_count, 
        color = colors[i], label = label)
    
    # Температура
    lines!(ax2, model_df[!, :time], model_df[!, :temperature], 
        color = colors[i])
    
    # Светимость (одинакова для всех)
    if i == 1
        lines!(ax3, model_df[!, :time], model_df[!, :solar_luminosity], 
            color = :black)
    end
end

for ax in (ax1, ax2); ax.xticklabelsvisible = false; end

Legend(figure[1, 2], ax1, "Параметры", labelsize = 10)

save(plotsdir("daisy_luminosity_comparison.png"), figure)
