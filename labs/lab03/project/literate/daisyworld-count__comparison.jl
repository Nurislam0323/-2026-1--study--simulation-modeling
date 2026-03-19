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
        scenario = :default,
        seed = 165,
        params...
    )
    agent_df, _ = run!(model, 1000; adata)
    push!(results, (params = params, df = agent_df, idx = i))
end

figure = Figure(size = (800, 500))
ax = Axis(figure[1, 1], 
    xlabel = "tick", 
    ylabel = "daisy count",
    title = "Сравнение динамики численности для разных параметров"
)

colors = [:blue, :green, :orange, :red]
markers = [:circle, :square, :diamond, :utriangle]

for (i, result) in enumerate(results)
    params = result.params
    df = result.df
    label = "max_age=$(params.max_age), init_white=$(params.init_white)"
    lines!(ax, df[!, :time], df[!, :count_black], 
        color = colors[i], linestyle = :solid, label = "black: $label")
    lines!(ax, df[!, :time], df[!, :count_white], 
        color = colors[i], linestyle = :dash, label = "white: $label")
end

Legend(figure[1, 2], ax, "Параметры", labelsize = 10)

save(plotsdir("daisy_count_comparison.png"), figure)
