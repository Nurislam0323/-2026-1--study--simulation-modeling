using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots, CSV
include(srcdir("../src/sir_model.jl"))

# ============================================================================
# ЗАДАНИЕ 3: Эффект гетерогенности — разные β для разных городов
# ============================================================================

println("="^60)
println("ЗАДАНИЕ 3: Эффект гетерогенности")
println("="^60)
println()

# Функция для запуска эксперимента с гетерогенными параметрами
function run_hetero_experiment(params)
    model = initialize_sir(; params...)
    
    times = Int[]
    S_vals = Int[]
    I_vals = Int[]
    R_vals = Int[]
    
    # Для статистики по городам
    I_city1 = Int[]
    I_city2 = Int[]
    I_city3 = Int[]
    
    for step = 1:params[:n_steps]
        Agents.step!(model, 1)
        push!(times, step)
        push!(S_vals, susceptible_count(model))
        push!(I_vals, infected_count(model))
        push!(R_vals, recovered_count(model))
        
        # Статистика по городам
        city1_agents = [a for a in allagents(model) if a.pos == 1]
        city2_agents = [a for a in allagents(model) if a.pos == 2]
        city3_agents = [a for a in allagents(model) if a.pos == 3]
        
        push!(I_city1, count(a -> a.status == :I, city1_agents))
        push!(I_city2, count(a -> a.status == :I, city2_agents))
        push!(I_city3, count(a -> a.status == :I, city3_agents))
    end
    
    return (
        times = times,
        S = S_vals,
        I = I_vals,
        R = R_vals,
        I_city1 = I_city1,
        I_city2 = I_city2,
        I_city3 = I_city3,
    )
end

# ============================================================================
# Сценарий 1: Гомгенный случай (одинаковые β)
# ============================================================================

println("Сценарий 1: Гомогенный случай (β одинаков для всех городов)")
println("-"^60)

params_homogeneous = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.5, 0.5, 0.5],  # Одинаковые
    :β_det => [0.05, 0.05, 0.05],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

result_homo = run_hetero_experiment(params_homogeneous)

peak_homo = maximum(result_homo.I)
println("Пик инфицированных: $(peak_homo) чел.")
println()

# ============================================================================
# Сценарий 2: Гетерогенный случай (разные β)
# ============================================================================

println("Сценарий 2: Гетерогенный случай (разные β для городов)")
println("-"^60)

params_heterogeneous = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.3, 0.5, 0.8],  # Разные значения!
    :β_det => [0.03, 0.05, 0.08],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [0, 0, 1],
    :seed => 42,
    :n_steps => 100,
)

println("Параметры заразности по городам:")
println("  Город 1: β = $(params_heterogeneous[:β_und][1]) (низкая)")
println("  Город 2: β = $(params_heterogeneous[:β_und][2]) (средняя)")
println("  Город 3: β = $(params_heterogeneous[:β_und][3]) (высокая)")
println()

result_hetero = run_hetero_experiment(params_heterogeneous)

peak_hetero = maximum(result_hetero.I)
println("Пик инфицированных (общий): $(peak_hetero) чел.")
println("Пик в городе 1: $(maximum(result_hetero.I_city1)) чел.")
println("Пик в городе 2: $(maximum(result_hetero.I_city2)) чел.")
println("Пик в городе 3: $(maximum(result_hetero.I_city3)) чел.")
println()

# ============================================================================
# Сценарий 3: Обратная гетерогенность
# ============================================================================

println("Сценарий 3: Обратная гетерогенность (эпидемия начинается в городе с низким β)")
println("-"^60)

params_reverse = Dict(
    :Ns => [1000, 1000, 1000],
    :β_und => [0.8, 0.5, 0.3],  # Эпидемия начинается в городе с низким β
    :β_det => [0.08, 0.05, 0.03],
    :infection_period => 14,
    :detection_time => 7,
    :death_rate => 0.02,
    :reinfection_probability => 0.1,
    :Is => [1, 0, 0],  # Начинается в первом городе
    :seed => 42,
    :n_steps => 100,
)

result_reverse = run_hetero_experiment(params_reverse)

peak_reverse = maximum(result_reverse.I)
println("Пик инфицированных (общий): $(peak_reverse) чел.")
println()

# ============================================================================
# Визуализация
# ============================================================================

println("="^60)
println("ВИЗУАЛИЗАЦИЯ")
println("="^60)

# График 1: Сравнение гомогенного и гетерогенного случаев
p1 = plot(
    result_homo.times,
    result_homo.I,
    label = "Гомогенный (β=0.5 везде)",
    xlabel = "Дни",
    ylabel = "Инфицированные",
    title = "Гомогенный vs Гетерогенный случай",
    linewidth = 2,
    color = :blue,
)

plot!(
    result_hetero.times,
    result_hetero.I,
    label = "Гетерогенный (β=[0.3, 0.5, 0.8])",
    linewidth = 2,
    color = :red,
)

savefig(plotsdir("hetero_comparison.png"))

# График 2: Динамика по городам для гетерогенного случая
p2 = plot(
    result_hetero.times,
    result_hetero.I_city1,
    label = "Город 1 (β=0.3)",
    xlabel = "Дни",
    ylabel = "Инфицированные",
    title = "Гетерогенность: динамика по городам",
    linewidth = 2,
)

plot!(result_hetero.times, result_hetero.I_city2, label = "Город 2 (β=0.5)", linewidth = 2)
plot!(result_hetero.times, result_hetero.I_city3, label = "Город 3 (β=0.8)", linewidth = 2)

savefig(plotsdir("hetero_by_city.png"))

# График 3: Все три сценария
p3 = plot(
    result_homo.times,
    result_homo.I,
    label = "Гомогенный",
    xlabel = "Дни",
    ylabel = "Инфицированные",
    title = "Сравнение трёх сценариев",
    linewidth = 2,
)

plot!(result_hetero.times, result_hetero.I, label = "Гетерогенный", linewidth = 2)
plot!(result_reverse.times, result_reverse.I, label = "Обратная гетерогенность", linewidth = 2)

savefig(plotsdir("hetero_all_scenarios.png"))

# Сохранение данных
@save datadir("heterogeneity_results.jld2") result_homo result_hetero result_reverse

println("✅ Графики сохранены:")
println("   plots/hetero_comparison.png")
println("   plots/hetero_by_city.png")
println("   plots/hetero_all_scenarios.png")
println()
println("📁 Данные: data/heterogeneity_results.jld2")
println()

# ============================================================================
# Выводы
# ============================================================================

println("="^60)
println("ВЫВОДЫ")
println("="^60)
println()
println("1. Гетерогенность приводит к тому, что пики в разных городах")
println("   наступают в разное время.")
println()
println("2. Город с высоким β заражается быстрее и имеет более высокий пик.")
println()
println("3. Общий пик эпидемии может быть ниже, чем в гомогенном случае,")
println("   так как эпидемия распространяется волнами.")
println()
println("4. Если эпидемия начинается в городе с низким β, общее распространение")
println("   замедляется, даже если другие города имеют высокий β.")
