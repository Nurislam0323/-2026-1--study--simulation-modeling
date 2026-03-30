using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots, CSV
include(srcdir("../src/sir_model.jl"))

# ============================================================================
# ЗАДАНИЕ 5: Карантинные меры — закрытие города при превышении порога
# ============================================================================

println("="^60)
println("ЗАДАНИЕ 5: Карантинные меры")
println("="^60)
println()

# Модифицированная функция шага модели с карантином
function sir_agent_step_with_quarantine!(agent, model)
    # Проверка карантина - в Agents.jl v7 используем getproperty/setproperty!
    quarantine_active = getproperty(model, :quarantine_active)
    quarantine_city = getproperty(model, :quarantine_city)
    
    # Если в этом городе карантин — миграция запрещена
    if !quarantine_active || agent.pos ≠ quarantine_city
        migrate!(agent, model)
    end

    # Передача инфекции
    if agent.status == :I
        transmit!(agent, model)
    end

    # Обновление счётчика
    if agent.status == :I
        agent.days_infected += 1
    end

    # Выздоровление или смерть
    recover_or_die!(agent, model)
end

# Функция проверки и введения карантина
function check_and_impose_quarantine!(model, current_day)
    quarantine_threshold = getproperty(model, :quarantine_threshold)
    quarantine_duration = getproperty(model, :quarantine_duration)
    quarantine_active = getproperty(model, :quarantine_active)
    quarantine_start_day = getproperty(model, :quarantine_start_day)
    quarantine_city = getproperty(model, :quarantine_city)
    
    C = getproperty(model, :C)
    
    for city = 1:C
        city_agents = [a for a in allagents(model) if a.pos == city]
        infected_in_city = count(a -> a.status == :I, city_agents)
        total_in_city = length(city_agents)
        
        if total_in_city > 0
            infection_rate = infected_in_city / total_in_city
            
            # Проверка порога для введения карантина
            if infection_rate > quarantine_threshold && !quarantine_active
                setproperty!(model, :quarantine_active, true)
                setproperty!(model, :quarantine_start_day, current_day)
                setproperty!(model, :quarantine_city, city)
                
                println("  ⚠️  ДЕНЬ $current_day: КАРАНТИН, город #$city")
                println("     Доля инфицированных: $(round(infection_rate*100, digits=1))%")
            end
        end
    end
    
    # Проверка окончания карантина
    if quarantine_active && current_day - quarantine_start_day >= quarantine_duration
        setproperty!(model, :quarantine_active, false)
        setproperty!(model, :quarantine_city, 0)
        println("  ✅ ДЕНЬ $current_day: КАРАНТИН снят")
    end
end

# Функция инициализации модели с карантином
function initialize_sir_with_quarantine(;
    Ns = [1000, 1000, 1000],
    migration_rates = nothing,
    β_und = [0.5, 0.5, 0.5],
    β_det = [0.05, 0.05, 0.05],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [0, 0, 1],
    seed = 42,
    n_steps = 100,
    quarantine_threshold = 0.05,
    quarantine_duration = 30,
)
    rng = Xoshiro(seed)
    C = length(Ns)

    if migration_rates === nothing
        migration_rates = zeros(C, C)
        for i = 1:C
            for j = 1:C
                migration_rates[i, j] = (Ns[i] + Ns[j]) / Ns[i]
            end
        end
        for i = 1:C
            migration_rates[i, :] ./= sum(migration_rates[i, :])
        end
    end

    properties = Dict(
        :Ns => Ns,
        :β_und => β_und,
        :β_det => β_det,
        :migration_rates => migration_rates,
        :infection_period => infection_period,
        :detection_time => detection_time,
        :death_rate => death_rate,
        :reinfection_probability => reinfection_probability,
        :C => C,
        :quarantine_threshold => quarantine_threshold,
        :quarantine_duration => quarantine_duration,
        :quarantine_active => false,
        :quarantine_start_day => 0,
        :quarantine_city => 0,
    )

    space = GraphSpace(complete_graph(C))
    model = StandardABM(
        Person,
        space;
        properties,
        rng,
        agent_step! = sir_agent_step_with_quarantine!,
    )

    for city = 1:C
        for _ = 1:Ns[city]
            add_agent!(city, model, 0, :S)
        end
    end

    for city = 1:C
        if Is[city] > 0
            city_agents = ids_in_position(city, model)
            infected_ids = sample(rng, city_agents, Is[city]; replace = false)
            for id in infected_ids
                agent = model[id]
                agent.status = :I
                agent.days_infected = 1
            end
        end
    end

    return model
end

# ============================================================================
# Запуск эксперимента с карантином
# ============================================================================

println("Параметры:")
println("  quarantine_threshold = 5% (доля инфицированных для введения)")
println("  quarantine_duration = 30 дней")
println()

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
    :n_steps => 150,
    :quarantine_threshold => 0.05,
    :quarantine_duration => 30,
)

# Модель с карантином
model = initialize_sir_with_quarantine(; params...)

times = Int[]
S_vals = Int[]
I_vals = Int[]
R_vals = Int[]
total_vals = Int[]
quarantine_flags = Bool[]

println("Запуск симуляции с карантином...")
println()

for step = 1:params[:n_steps]
    # Проверка карантина перед шагом
    check_and_impose_quarantine!(model, step)
    
    Agents.step!(model, 1)
    
    push!(times, step)
    push!(S_vals, susceptible_count(model))
    push!(I_vals, infected_count(model))
    push!(R_vals, recovered_count(model))
    push!(total_vals, total_count(model))
    push!(quarantine_flags, getproperty(model, :quarantine_active))
end

println()
println("Симуляция завершена.")
println()

# ============================================================================
# Запуск без карантина для сравнения
# ============================================================================

println("Запуск симуляции БЕЗ карантина (для сравнения)...")
println()

model_no_quarantine = initialize_sir(;
    Ns = params[:Ns],
    β_und = params[:β_und],
    β_det = params[:β_det],
    infection_period = params[:infection_period],
    detection_time = params[:detection_time],
    death_rate = params[:death_rate],
    reinfection_probability = params[:reinfection_probability],
    Is = params[:Is],
    seed = params[:seed],
    n_steps = params[:n_steps],
)

times_nq = Int[]
I_vals_nq = Int[]
deaths_nq = Int[]

for step = 1:params[:n_steps]
    Agents.step!(model_no_quarantine, 1)
    push!(times_nq, step)
    push!(I_vals_nq, infected_count(model_no_quarantine))
    push!(deaths_nq, 3000 - total_count(model_no_quarantine))
end

println("Симуляция завершена.")
println()

# ============================================================================
# Сравнение результатов
# ============================================================================

println("="^60)
println("СРАВНЕНИЕ РЕЗУЛЬТАТОВ")
println("="^60)
println()

peak_with = maximum(I_vals)
peak_without = maximum(I_vals_nq)

deaths_with = 3000 - total_vals[end]
deaths_without = deaths_nq[end]

println("Пик инфицированных:")
println("  С карантином:     $(peak_with) чел. ($(round(peak_with/3000*100, digits=1))%)")
println("  Без карантина:    $(peak_without) чел. ($(round(peak_without/3000*100, digits=1))%)")
println("  Снижение пика:    $(peak_without - peak_with) чел. ($(round((1 - peak_with/peak_without)*100, digits=1))%)")
println()

println("Умершие:")
println("  С карантином:     $(deaths_with) чел.")
println("  Без карантина:    $(deaths_without) чел.")
println("  Спасённых жизней: $(deaths_without - deaths_with)")
println()

# Проверка эффективности
if peak_with < peak_without * 0.7
    println("✅ Карантин ЭФФЕКТИВЕН: пик снижен более чем на 30%")
elseif peak_with < peak_without * 0.9
    println("✅ Карантин УМЕРЕННО эффективен: пик снижен на 10-30%")
else
    println("⚠️  Карантин МАЛОэффективен: пик снижен менее чем на 10%")
end

println()

# ============================================================================
# Визуализация
# ============================================================================

println("="^60)
println("ВИЗУАЛИЗАЦИЯ")
println("="^60)

# График 1: Сравнение динамики с карантином и без
p1 = plot(
    times,
    I_vals,
    label = "С карантином",
    xlabel = "Дни",
    ylabel = "Инфицированные",
    title = "Эффект карантина (порог 5%, 30 дней)",
    linewidth = 2,
    color = :green,
)

plot!(
    times_nq,
    I_vals_nq,
    label = "Без карантина",
    linewidth = 2,
    color = :red,
    linestyle = :dash,
)

# Аннотация периода карантина
quarantine_start = findfirst(quarantine_flags)
quarantine_end = findlast(quarantine_flags)

if quarantine_start !== nothing && quarantine_end !== nothing
    annotate!([
        (times[quarantine_start], peak_with + 100, text("📍 Карантин", :left, :black, 10)),
    ])
    
    # Закрашиваем период карантина
    plot!([times[quarantine_start], times[quarantine_end]], [0, 0], 
          label = "", fillrange = maximum(I_vals), fillalpha = 0.1, color = :yellow, linewidth = 0)
end

savefig(plotsdir("quarantine_effect.png"))

# График 2: Динамика с аннотациями
p2 = plot(
    times,
    I_vals,
    label = "Инфицированные",
    xlabel = "Дни",
    ylabel = "Количество",
    title = "Динамика эпидемии с карантином",
    linewidth = 2,
)

plot!(times, S_vals, label = "Восприимчивые", linewidth = 2)
plot!(times, R_vals, label = "Выздоровевшие", linewidth = 2)

if quarantine_start !== nothing && quarantine_end !== nothing
    vspan!([times[quarantine_start], times[quarantine_end]], 
           label = "Период карантина", alpha = 0.2, color = :yellow)
end

savefig(plotsdir("quarantine_dynamics.png"))

# Сохранение данных
agent_df = DataFrame(time = times, susceptible = S_vals, infected = I_vals, recovered = R_vals)
@save datadir("quarantine_results.jld2") agent_df peak_with peak_without deaths_with deaths_without

println("✅ Графики сохранены:")
println("   plots/quarantine_effect.png")
println("   plots/quarantine_dynamics.png")
println()
println("📁 Данные: data/quarantine_results.jld2")
