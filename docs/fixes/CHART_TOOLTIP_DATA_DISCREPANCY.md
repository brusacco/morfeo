# 🐛 BUG: Discrepancia entre Gráfico y Tooltip en "Evolución Temporal"

## Descripción del Problema

**Ubicación**: Dashboard de Digitales (`/topic/:id`) - Sección "Evolución Temporal"  
**Gráfico afectado**: "Notas por Día" (column chart)

**Síntoma**: Al hacer click en una barra del gráfico, el modal muestra una cantidad de notas diferente al valor de la barra.

### Ejemplo
- **Barra del gráfico**: Muestra "15 notas"
- **Modal al hacer click**: Muestra "12 notas" en la lista

---

## Causa Raíz

Hay **dos fuentes de datos diferentes**:

### 1. Datos del Gráfico (TopicStatDaily - Pre-agregado)

```ruby
# Archivo: app/services/digital_dashboard_services/aggregator_service.rb
# Líneas: 115-133

def load_chart_data
  # USA TopicStatDaily (tabla de estadísticas pre-calculadas)
  topic_stats = @topic.topic_stat_dailies
                      .where(topic_date: @start_date.to_date..@end_date.to_date)
                      .order(:topic_date).to_a

  stats.each do |stat|
    chart_entries_counts[date] = stat.entry_count  # ← VALOR DE LA BARRA
  end
end
```

**Características**:
- ✅ Rápido (pre-calculado)
- ❌ Puede estar desactualizado
- ❌ Calculado por job programado
- 📊 Campo: `TopicStatDaily.entry_count`

### 2. Datos del Tooltip (Entries - Tiempo Real)

```ruby
# Archivo: app/controllers/topic_controller.rb
# Líneas: 13-76 (método entries_data)

def entries_data
  # USA topic.chart_entries(date) - consulta directa a entries
  entries = if title == 'true'
              topic.title_chart_entries(date)
            else
              topic.chart_entries(date)  # ← VALOR DEL MODAL
            end

  # Retorna lista real de entries
  render partial: 'home/chart_entries',
         locals: { topic_entries: entries, ... }
end
```

**Características**:
- ✅ Actualizado en tiempo real
- ✅ Refleja estado actual (enabled/disabled)
- ❌ Más lento (consulta en cada click)
- 📊 Campo: `entries.count` (ActiveRecord query)

---

## ¿Por qué hay diferencia?

### Causa 1: TopicStatDaily Desactualizado

Los stats se actualizan mediante job programado:

```ruby
# config/schedule.rb
# Corre cada X horas (no en tiempo real)
```

Si un entry se crea, actualiza o deshabilita **entre ejecuciones del job**, los stats no reflejan el cambio.

### Causa 2: Filtros Diferentes

**chart_entries (tiempo real)**:
```ruby
# app/models/topic.rb:168-192
def chart_entries(date)
  entries.enabled  # ← Solo entries habilitados
         .where(published_at: date.beginning_of_day..date.end_of_day)
         .order(total_count: :desc)
         .joins(:site)
end
```

**TopicStatDaily (pre-calculado)**:
```ruby
# Puede usar criterios diferentes al momento de calcular
# No sabemos exactamente qué filtros aplicó el job
```

### Causa 3: Cambios en Tags

Si un entry:
- Se le agregan/quitan tags
- Pasa a matchear o dejar de matchear el topic

...el `chart_entries` lo reflejará **inmediatamente**, pero `TopicStatDaily` no se actualiza hasta el próximo job.

### Causa 4: Entries Deshabilitados

Si un entry se deshabilita (`enabled: false`):
- `chart_entries` lo excluye ✅
- `TopicStatDaily` puede incluirlo si se calculó antes ❌

---

## Impacto

### En el Usuario
- ⚠️ **Confusión**: Los números no cuadran
- ⚠️ **Desconfianza**: "¿Los datos son correctos?"
- ⚠️ **CEO Experience**: Impacto negativo en presentaciones

### En el Sistema
- ℹ️ **No crítico**: Ambas fuentes son válidas, solo en momentos diferentes
- ℹ️ **No hay pérdida de datos**: Es solo una inconsistencia temporal

---

## Soluciones Propuestas

### ✅ Opción 1: Unificar Fuente de Datos (RECOMENDADO)

**Usar la misma fuente para gráfico y tooltip**

#### Opción 1A: TopicStatDaily en ambos
```ruby
# Ventaja: Consistencia, performance
# Desventaja: Datos no actualizados en tiempo real

# Actualizar entries_data controller:
def entries_data
  stat = @topic.topic_stat_dailies.find_by(topic_date: date.to_date)
  entry_ids = stat&.entry_ids || []  # Necesitaríamos guardar los IDs
  entries = Entry.where(id: entry_ids).order(total_count: :desc)
end
```

**Problema**: TopicStatDaily no guarda los `entry_ids`, solo agregados.

#### Opción 1B: chart_entries en ambos
```ruby
# Ventaja: Datos en tiempo real, consistencia
# Desventaja: Performance (más lento)

# Actualizar load_chart_data en servicio:
def load_chart_data
  dates = (@start_date.to_date..@end_date.to_date).to_a
  chart_entries_counts = dates.map do |date|
    [date, @topic.chart_entries(date).count]  # Query por cada día
  end.to_h
end
```

**Problema**: N+1 queries (una por día), muy lento.

---

### ✅ Opción 2: Mantener TopicStatDaily pero Mejorar (ÓPTIMO)

**Continuar usando TopicStatDaily para gráficos, pero mejorar sincronización**

#### Paso 1: Agregar columna `entry_ids` a TopicStatDaily

```ruby
# Migration
add_column :topic_stat_dailies, :entry_ids, :json, default: []
add_index :topic_stat_dailies, :entry_ids, using: :gin  # Para búsquedas rápidas
```

#### Paso 2: Actualizar job para guardar IDs

```ruby
# lib/tasks/update_topic_stats.rake o similar
def calculate_daily_stats(topic, date)
  entries = topic.chart_entries(date)
  
  TopicStatDaily.find_or_create_by(topic: topic, topic_date: date) do |stat|
    stat.entry_count = entries.count
    stat.total_count = entries.sum(:total_count)
    stat.entry_ids = entries.pluck(:id)  # ← GUARDAR IDs
    # ... otros campos
  end
end
```

#### Paso 3: Actualizar controller para usar IDs guardados

```ruby
# app/controllers/topic_controller.rb
def entries_data
  stat = @topic.topic_stat_dailies.find_by(topic_date: date.to_date)
  
  if stat&.entry_ids.present?
    # Usar IDs del stat (consistente con gráfico)
    entries = Entry.where(id: stat.entry_ids).enabled.order(total_count: :desc)
  else
    # Fallback a tiempo real si no hay stat
    entries = topic.chart_entries(date)
  end
  
  render partial: 'home/chart_entries', locals: { topic_entries: entries, ... }
end
```

**Ventajas**:
- ✅ Consistencia total entre gráfico y tooltip
- ✅ Performance excelente (un query simple)
- ✅ Fallback a tiempo real si stats no existen
- ✅ Fácil debugging (puedes comparar counts vs entry_ids.length)

---

### ✅ Opción 3: Disclaimer en UI

**Agregar mensaje explicativo**

```erb
<!-- En app/views/topic/show.html.erb -->
<div class="bg-blue-50 border-l-4 border-blue-400 p-3 mb-4">
  <p class="text-xs text-blue-700">
    <i class="fa-solid fa-info-circle mr-1"></i>
    <strong>Nota:</strong> Los gráficos usan datos pre-calculados para performance.
    Los detalles al hacer click muestran datos en tiempo real, por lo que pueden
    diferir ligeramente.
  </p>
</div>
```

**Ventajas**:
- ✅ Sin cambios de código
- ✅ Transparencia con el usuario
- ❌ No soluciona el problema real

---

### ✅ Opción 4: Cache Busting

**Invalidar cache de stats al cambiar entries**

```ruby
# app/models/entry.rb
after_commit :invalidate_topic_stats, on: [:create, :update, :destroy]

def invalidate_topic_stats
  # Forzar recálculo del stat del día
  topic_ids = self.entry_topics.pluck(:topic_id)
  topics = Topic.where(id: topic_ids)
  
  topics.each do |topic|
    # Recalcular stat del día de la publicación
    RecalculateTopicStatJob.perform_later(topic.id, published_at.to_date)
  end
end
```

**Ventajas**:
- ✅ Stats siempre actualizados
- ❌ Performance impact (muchos jobs)
- ❌ Complejo de mantener

---

## Recomendación Final

### 🎯 **Implementar Opción 2: Guardar entry_ids en TopicStatDaily**

**Por qué**:
1. **Consistencia**: Ambas fuentes usan los mismos datos
2. **Performance**: Mantiene velocidad de carga
3. **Transparencia**: CEO puede confiar en los números
4. **Simple**: Un campo extra, sin cambios arquitectónicos mayores

**Pasos de implementación**:

1. **Migration** (5 min)
```bash
rails g migration AddEntryIdsToTopicStatDailies entry_ids:jsonb
```

2. **Actualizar job** (10 min)
```ruby
# En lib/tasks/topic_stats.rake o similar
stat.entry_ids = entries.pluck(:id)
```

3. **Actualizar controller** (10 min)
```ruby
# En app/controllers/topic_controller.rb#entries_data
entries = Entry.where(id: stat.entry_ids)
```

4. **Testing** (15 min)
- Verificar que gráfico y modal muestran mismos valores
- Test con entries enabled/disabled
- Test con cambios de tags

**Tiempo total**: ~40 minutos

---

## Testing Manual

Para verificar el problema:

1. Ir a `/topic/1` (o cualquier topic)
2. En "Evolución Temporal", ver el valor de una barra (ej: "15 notas")
3. Hacer click en esa barra
4. Contar las entries en el modal
5. Comparar: ¿coinciden los números?

---

## Archivos Involucrados

### Fuentes de Datos
- `app/services/digital_dashboard_services/aggregator_service.rb:115-166`
- `app/controllers/topic_controller.rb:13-76`
- `app/models/topic.rb:168-192`

### Modelos
- `app/models/topic_stat_daily.rb` (stats pre-calculados)
- `app/models/entry.rb` (entries reales)
- `app/models/topic.rb` (métodos de consulta)

### Jobs
- `lib/tasks/*.rake` (actualización de stats)

### Vista
- `app/views/topic/show.html.erb:322-342` (gráfico)
- `app/views/home/_chart_entries.html.erb` (modal)

---

## Notas Adicionales

### ¿Por qué TopicStatDaily existe?

**Performance**: Calcular aggregados en tiempo real para 60+ días es **muy lento**:

```ruby
# Esto haría 60 queries (una por día):
60.times do |i|
  date = i.days.ago
  count = topic.chart_entries(date).count  # Query pesado
end
```

**Con TopicStatDaily**: Un solo query para 60 días:
```ruby
topic.topic_stat_dailies.where(topic_date: 60.days.ago..Date.today).pluck(:topic_date, :entry_count)
```

**Resultado**: 10x-50x más rápido en dashboards.

---

**Status**: 🔴 **BUG CONFIRMADO - PENDIENTE DE FIX**  
**Prioridad**: ⚠️ **MEDIA** (afecta UX pero no es crítico)  
**Complejidad**: 🟢 **BAJA** (solución clara, implementación simple)  
**Tiempo Estimado**: 40 minutos

---

**Próximos pasos**:
1. Confirmar con CEO/Product si es prioritario
2. Crear ticket en sistema de issues
3. Implementar Opción 2 (entry_ids)
4. Testing extensivo
5. Deploy y monitoreo

