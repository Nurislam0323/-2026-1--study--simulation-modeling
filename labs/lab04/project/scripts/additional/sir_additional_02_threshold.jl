using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots, CSV, Random, Statistics
include(srcdir("../src/sir_model.jl"))

# ============================================================================
# ЗАДАНИЕ 2: Исследование порога эпидемии
# ============================================================================

println("="^60)
println("ЗАДАНИЕ 2: Исследование порога эпидемии")
println("="^60)
println()

# Функция для запуска одного эксперимента
function run_experiment(p)
    beta = p[:beta]
    β_und = fill(beta, 3)
    β_det = fill(beta/10, 3)

    model = initialize_sir(;
        Ns = p[:Ns],
        β_und = β_und,
        β_det = β_det,
        infection_period = p[:infection_period],
        detection_time = p[:detection_time],
        death_rate = p[:death_rate],
        reinfection_probability = p[:reinfection_probability],
        Is = p[:Is],
        seed = p[:seed],
        n_steps = p[:n_steps],
    )

    infected_fraction(model) = count(a.status == :I for a in allagents(model)) / nagents(model)
    peak_infected = 0.0

    for step = 1:p[:n_steps]
        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing
            end
            if agent !== nothing
                sir_agent_step!(agent, model)
            end
        end
        frac = infected_fraction(model)
        if frac > peak_infected
            peak_infected = frac
        end
    end

    final_infected = infected_fraction(model)
    final_recovered = count(a.status == :R for a in allagents(model)) / nagents(model)
    total_deaths = sum(p[:Ns]) - nagents(model)

    return (
        peak = peak_infected,
        final_inf = final_infected,
        final_rec = final_recovered,
        deaths = total_deaths,
    )
end

# ============================================================================
# Сканирование с мелким шагом около порога
# ============================================================================

# Теоретический порог: R₀ = 1 ⇒ β = γ = 1/14 ≈ 0.071
# Но в агентной модели с тремя городами β_und применяется ко всем городам
# Поэтому нужен больший диапазон для возникновения эпидемии
# Будем сканировать от 0.1 до 0.5 с шагом 0.02
beta_range = 0.10:0.02:0.50
seeds = [42, 43, 44]

println("Диапазон сканирования β: от $(minimum(beta_range)) до $(maximum(beta_range))")
println("Теоретический порог R₀ = 1: β = $(round(1/14, digits=4))")
println("Примечание: в модели β_und применяется ко всем городам одновременно")
println()

params_list = []
for b in beta_range
    for s in seeds
        push!(
            params_list,
            Dict(
                :beta => b,
                :Ns => [1000, 1000, 1000],
                :infection_period => 14,
                :detection_time => 7,
                :death_rate => 0.02,
                :reinfection_probability => 0.1,
                :Is => [0, 0, 1],
                :seed => s,
                :n_steps => 100,
            ),
        )
    end
end

# Запуск экспериментов
results = []
for params in params_list
    data = run_experiment(params)
    push!(results, merge(params, Dict(pairs(data))))
    println("β = $(params[:beta]), seed = $(params[:seed]), peak = $(round(data.peak, digits=3))")
end

# Сохраняем все прогоны
df = DataFrame(results)
CSV.write(datadir("threshold_scan_all.csv"), df)

# Усреднение по повторам
grouped = combine(
    groupby(df, [:beta]),
    :peak => mean => :mean_peak,
    :final_inf => mean => :mean_final_inf,
    :deaths => mean => :mean_deaths,
)

# ============================================================================
# Нахождение порогового значения (пик > 5%)
# ============================================================================

println()
println("="^60)
println("РЕЗУЛЬТАТЫ: Поиск порогового значения")
println("="^60)

# Теоретический порог
β_theory = 1 / 14
println()
println("📐 Теоретический порог (R₀ = 1):")
println("   β_theory = 1/14 = $(round(β_theory, digits=4))")
println()

# Находим минимальное β, при котором пик > 5%
threshold_rows = grouped[grouped.mean_peak .> 0.05, :]

if !isempty(threshold_rows)
    β_threshold = threshold_rows.beta[1]
    peak_at_threshold = threshold_rows.mean_peak[1]
    
    println()
    println("✅ Минимальное β для эпидемии (пик > 5%):")
    println("   β_min = $(β_threshold)")
    println("   Пик при этом β: $(round(peak_at_threshold*100, digits=2))%")
    println()
    
    # Сравнение
    println("📊 Сравнение:")
    println("   Отклонение: $(round((β_threshold - β_theory)/β_theory*100, digits=1))%")
    println()
    
    if β_threshold ≈ β_theory atol=0.02
        println("✅ Экспериментальный порог близок к теоретическому!")
    else
        println("⚠️  Экспериментальный порог отличается от теоретического.")
        println("   Это связано со стохастичностью агентной модели.")
    end
else
    println("⚠️  Не найдено β в диапазоне $(minimum(beta_range))-$(maximum(beta_range)), при котором пик > 5%")
    println("   Попробуйте увеличить диапазон сканирования.")
    println()
    println("📊 Максимальный пик в эксперименте:")
    max_peak_row = grouped[argmax(grouped.mean_peak), :]
    println("   β = $(max_peak_row.beta), пик = $(round(max_peak_row.mean_peak*100, digits=2))%")
end

println()

# ============================================================================
# Визуализация
# ============================================================================

# График 1: Зависимость пика от β с аннотацией порога
p1 = plot(
    grouped.beta,
    grouped.mean_peak,
    label = "Пик эпидемии",
    xlabel = "Коэффициент заразности β",
    ylabel = "Доля инфицированных",
    marker = :circle,
    linewidth = 2,
    title = "Порог эпидемии (пик > 5%)",
)

# Линия порога 5%
hline!([0.05], label = "Порог 5%", linestyle = :dash, color = :red, linewidth = 2)

# Аннотация найденного порога
if !isempty(threshold_rows)
    vline!([β_threshold], label = "β_min = $(β_threshold)", linestyle = :dot, color = :green, linewidth = 2)
    annotate!([(β_threshold, 0.06, text("β_min = $(β_threshold)", :left, :green, 10))])
end

# Линия теоретического порога
vline!([β_theory], label = "R₀ = 1 (теория)", linestyle = :dash, color = :blue, linewidth = 2)

savefig(plotsdir("threshold_analysis.png"))

# График 2: Область затухания vs область роста
p2 = plot(
    grouped.beta,
    grouped.mean_peak,
    label = "Пик",
    xlabel = "β",
    ylabel = "Доля инфицированных",
    marker = :circle,
    linewidth = 2,
    fillrange = 0,
    fillalpha = 0.3,
)

hline!([0.05], label = "Порог 5%", linestyle = :dash, color = :red)
vline!([β_theory], label = "R₀ = 1", linestyle = :dash, color = :blue)

# Закрашиваем области
plot!([0.05, β_theory], [0, 0], label = "", fillrange = maximum(grouped.mean_peak), 
      fillalpha = 0.1, color = :red, linewidth = 0)
annotate!([(0.07, 0.08, text("Эпидемия\nзатухает", :center, :red, 9))])
annotate!([(0.12, 0.08, text("Эпидемия\nрастёт", :center, :green, 9))])

savefig(plotsdir("threshold_regions.png"))

println("✅ Графики сохранены:")
println("   plots/threshold_analysis.png")
println("   plots/threshold_regions.png")
println()
println("📁 Данные: data/threshold_scan_all.csv")
