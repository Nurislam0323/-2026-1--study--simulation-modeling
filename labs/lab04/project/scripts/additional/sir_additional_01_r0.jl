using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots
using JLD2
include(srcdir("../src/sir_model.jl"))

# Параметры эксперимента (по умолчанию из инструкции)
params = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.5, 0.5, 0.5],
    :β_det => [0.05, 0.05, 0.05],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

# ============================================================================
# ЗАДАНИЕ 1: Базовый уровень — вычисление R₀
# ============================================================================

println("="^60)
println("ЗАДАНИЕ 1: Базовый уровень — Вычисление R₀")
println("="^60)

# Вычисление базового репродуктивного числа R₀
# Формула: R₀ = β/γ, где γ = 1/infection_period
β = params[:β_und][1]  # берём для первого города
γ = 1 / params[:infection_period]
R₀ = β / γ

println()
println("Параметры модели:")
println("  β_und = $(params[:β_und][1]) (коэффициент заразности)")
println("  infection_period = $(params[:infection_period]) дней")
println("  γ = 1/infection_period = $(round(γ, digits=4))")
println()
println("Базовое репродуктивное число:")
println("  R₀ = β/γ = $(round(R₀, digits=2))")
println()
println("Интерпретация:")
println("  R₀ > 1 ⇒ эпидемия возникает и распространяется")
println("  R₀ < 1 ⇒ эпидемия затухает")
println()
println("Для сравнения:")
println("  • Сезонный грипп: R₀ ≈ 1.3")
println("  • COVID-19 (оригинальный): R₀ ≈ 2.5-3")
println("  • COVID-19 (дельта): R₀ ≈ 5-7")
println("  • Корь: R₀ ≈ 12-18")
println()

# Инициализация модели
model = initialize_sir(; params...)

# Подготовка массивов для хранения данных
times = Int[]
S_vals = Int[]
I_vals = Int[]
R_vals = Int[]
total_vals = Int[]

# Запуск симуляции
for step = 1:params[:n_steps]
    Agents.step!(model, 1)
    push!(times, step)
    push!(S_vals, susceptible_count(model))
    push!(I_vals, infected_count(model))
    push!(R_vals, recovered_count(model))
    push!(total_vals, total_count(model))
end

# Создаём DataFrame
agent_df = DataFrame(
    time = times,
    susceptible = S_vals,
    infected = I_vals,
    recovered = R_vals
)
model_df = DataFrame(time = times, total = total_vals)

# Визуализация с аннотацией R₀
plot(
    agent_df.time,
    agent_df.susceptible,
    label = "Восприимчивые (S)",
    xlabel = "Дни",
    ylabel = "Количество",
    title = "Базовый эксперимент SIR\nR₀ = $(round(R₀, digits=2)) (β = $(β), γ = $(round(γ, digits=3)))",
    linewidth = 2,
)
plot!(agent_df.time, agent_df.infected, label = "Инфицированные (I)", linewidth = 2)
plot!(agent_df.time, agent_df.recovered, label = "Выздоровевшие (R)", linewidth = 2)
plot!(agent_df.time, model_df.total, label = "Всего (включая умерших)", linestyle = :dash, linewidth = 2)

# Добавляем аннотацию с R₀
annotate!([(50, 2800, text("R₀ = $(round(R₀, digits=2))\nЭпидемия возникнет", :left, :green, 10))])

savefig(plotsdir("sir_basic_with_r0.png"))

# Сохранение данных
@save datadir("sir_basic_with_r0.jld2") agent_df model_df R₀ β γ

println("✅ График сохранён: plots/sir_basic_with_r0.png")
println("✅ Данные сохранены: data/sir_basic_with_r0.jld2")
println()

# Проверка наблюдаемой динамики
peak_infected = maximum(I_vals)
final_infected = I_vals[end]
total_ill = params[:Ns][1] * 3 - S_vals[end]

println("Наблюдаемая динамика:")
println("  Пик инфицированных: $(peak_infected) чел. ($(round(peak_infected/3000*100, digits=1))%)")
println("  Всего переболело: $(total_ill) чел. ($(round(total_ill/3000*100, digits=1))%)")
println("  Умерло: $(3000 - total_vals[end]) чел.")
println()
println("Вывод: При R₀ = $(round(R₀, digits=2)) > 1 эпидемия возникла, что согласуется с теорией.")
