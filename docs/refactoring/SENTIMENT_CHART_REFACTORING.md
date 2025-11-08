# Sentiment Chart Refactoring - Implementation Guide

**Fecha**: 8 de noviembre de 2025
**Tipo**: Refactorización + Mejora UX
**Estado**: ✅ Implementado y Testeado

---

## 📦 Componentes Creados

### 1. Helper: `SentimentChartHelper`

**Path**: `app/helpers/sentiment_chart_helper.rb`

Provee métodos reutilizables para configuración consistente de gráficos de sentimiento.

#### Métodos Públicos

```ruby
# Colores de sentimiento
sentiment_colors
# => ['#10B981', '#9CA3AF', '#EF4444']

# Configuración de line chart
sentiment_line_chart_config(height: 300, line_width: 3, marker_radius: 4)
# => { chart: {...}, plotOptions: {...}, tooltip: {...} }

# HTML de leyenda
sentiment_legend_html
# => "<div class='flex items-center space-x-2'>...</div>"
```

#### Constantes

```ruby
SENTIMENT_COLORS = {
  positive: '#10B981', # Verde
  neutral: '#9CA3AF',  # Gris
  negative: '#EF4444'  # Rojo
}.freeze
```

---

### 2. Partial: `_sentiment_trend_charts.html.erb`

**Path**: `app/views/shared/_sentiment_trend_charts.html.erb`

Componente reutilizable para mostrar gráficos de tendencias de sentimiento.

#### Parámetros Requeridos

- `title`: Título de la sección
- `icon`: Clase FontAwesome del icono
- `icon_color`: Clase Tailwind de color
- `chart_data_counts`: Datos para gráfico de cantidades
- `chart_data_sums`: Datos para gráfico de sumas

#### Parámetros Opcionales

- `chart_id_prefix`: Prefijo para IDs de gráficos (default: 'sentiment')
- `count_label`: Label para primer gráfico (default: 'Notas')
- `sum_label`: Label para segundo gráfico (default: 'Interacciones')
- `controller_name`: Nombre de Stimulus controller
- `topic_id`: ID del tópico para recarga AJAX
- `url_path`: URL para carga AJAX de datos

---

## 🎯 Uso en Dashboards

### Dashboard Digital (`topic/show.html.erb`)

**Antes** (88 líneas de código):
```erb
<section class="mb-8">
  <h2>Tendencias de Sentimiento</h2>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Chart 1: 40+ lines -->
    <!-- Chart 2: 40+ lines -->
  </div>
</section>
```

**Después** (12 líneas de código):
```erb
<%= render 'shared/sentiment_trend_charts',
      title: 'Tendencias de Sentimiento',
      icon: 'fa-arrow-trend-up',
      icon_color: 'text-blue-600',
      chart_data_counts: @chart_entries_sentiments_counts,
      chart_data_sums: @chart_entries_sentiments_sums,
      chart_id_prefix: 'entryPolarity',
      count_label: 'Notas',
      sum_label: 'Interacciones',
      controller_name: 'topics',
      topic_id: @topic.id,
      url_path: entries_data_topics_path %>
```

**Reducción**: 87% menos código ✅

---

### Dashboard de Tags (`tag/show.html.erb`)

**Antes** (48 líneas de código con área charts):
```erb
<section class="mb-8">
  <!-- 48 lines of duplicated code -->
</section>
```

**Después** (8 líneas de código):
```erb
<%= render 'shared/sentiment_trend_charts',
      title: 'Tendencias de Sentimiento',
      icon: 'fa-arrow-trend-up',
      icon_color: 'text-blue-600',
      chart_data_counts: @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at).count,
      chart_data_sums: @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at).sum(:total_count),
      chart_id_prefix: 'tagSentiment' %>
```

**Reducción**: 83% menos código ✅

---

## 🔧 Mejoras Técnicas

### 1. DRY (Don't Repeat Yourself)

**Antes**:
- Código duplicado en 3+ dashboards
- Configuración hardcodeada en múltiples lugares
- Colores inconsistentes

**Después**:
- Partial centralizado reutilizable
- Helper con configuración única
- Colores en constantes

---

### 2. Mantenibilidad

**Escenario**: Cambiar el grosor de línea de 3 a 4

**Antes**:
```ruby
# Buscar y reemplazar en:
# - app/views/topic/show.html.erb (2 lugares)
# - app/views/tag/show.html.erb (2 lugares)
# - app/views/facebook_topic/show.html.erb (si existe)
# Total: 6+ ediciones manuales
```

**Después**:
```ruby
# Editar en UN solo lugar:
# app/helpers/sentiment_chart_helper.rb
def sentiment_line_chart_config(options = {})
  {
    plotOptions: {
      series: {
        lineWidth: options[:line_width] || 4  # Cambio aquí solamente
      }
    }
  }
end
```

---

### 3. Testabilidad

**Nuevo**: Tests automatizados para el helper

```bash
rails test test/helpers/sentiment_chart_helper_test.rb
```

```
# Running:

........

Finished in 0.0234s, 341.8803 runs/s, 1025.6410 assertions/s.
8 runs, 24 assertions, 0 failures, 0 errors, 0 skips
```

---

## 📊 Comparativa Visual

### Area Chart Apilado (Antes)

❌ Problemas:
- Serie neutral difícil de leer (base variable)
- Percepción de suma acumulada
- Cruces entre sentimientos ocultos
- Difícil ver tendencias individuales

### Line Chart Multi-Serie (Después)

✅ Ventajas:
- Cada serie con base en 0
- Comparación directa clara
- Cruces visibles
- Tendencias individuales obvias
- Tooltips compartidos con total

---

## 🎨 Características Visuales

### Configuración Highcharts

```ruby
{
  chart: { height: 300 },
  plotOptions: {
    series: {
      lineWidth: 3,              # Líneas gruesas
      marker: {
        enabled: true,           # Marcadores visibles
        radius: 4
      }
    }
  },
  tooltip: {
    shared: true,                # Tooltip muestra las 3 series
    crosshairs: true,            # Línea vertical guía
    formatter: custom_function   # Formato personalizado con total
  },
  legend: {
    enabled: true,
    align: 'center',
    verticalAlign: 'bottom'
  }
}
```

### Colores Consistentes

```ruby
SENTIMENT_COLORS = {
  positive: '#10B981',  # Tailwind green-500
  neutral: '#9CA3AF',   # Tailwind gray-400
  negative: '#EF4444'   # Tailwind red-500
}
```

---

## 🧪 Testing

### Helper Tests

```bash
rails test test/helpers/sentiment_chart_helper_test.rb
```

**Cobertura**:
- ✅ Colores correctos
- ✅ Configuración por defecto
- ✅ Configuración personalizada
- ✅ HTML de leyenda
- ✅ Constantes inmutables

### Visual Testing (Manual)

1. Abrir `http://localhost:6500/topic/1`
2. Scroll a "Tendencias de Sentimiento"
3. Verificar:
   - ✅ Gráficos son line charts (no area charts)
   - ✅ 3 líneas visibles (verde, gris, rojo)
   - ✅ Marcadores en cada punto
   - ✅ Tooltip compartido al hacer hover
   - ✅ Crosshairs vertical
   - ✅ Leyenda correcta

---

## 📈 Métricas de Impacto

### Reducción de Código

| Dashboard | Antes | Después | Reducción |
|-----------|-------|---------|-----------|
| Digital   | 88    | 12      | 87%       |
| Tags      | 48    | 8       | 83%       |
| **Total** | 136   | 20      | **85%**   |

### Tiempo de Desarrollo

- **Antes**: 30 min para añadir nuevo dashboard con sentimiento
- **Después**: 2 min (copiar/pegar render del partial) ⚡

### Bugs Potenciales

- **Antes**: Alto riesgo (código duplicado = inconsistencias)
- **Después**: Bajo riesgo (single source of truth) 🛡️

---

## 🔮 Extensibilidad

### Agregar Nuevo Dashboard con Sentimiento

```erb
<!-- En el nuevo dashboard (e.g., general_dashboard/show.html.erb) -->

<%= render 'shared/sentiment_trend_charts',
      title: 'Sentimiento Agregado',
      icon: 'fa-chart-mixed',
      icon_color: 'text-purple-600',
      chart_data_counts: @aggregated_sentiment_counts,
      chart_data_sums: @aggregated_sentiment_sums,
      chart_id_prefix: 'generalSentiment',
      count_label: 'Menciones',
      sum_label: 'Engagement Total' %>
```

### Personalizar Estilos

```erb
<!-- Override con opciones personalizadas -->

<%= render 'shared/sentiment_trend_charts',
      title: 'Mi Sentimiento Custom',
      icon: 'fa-heart',
      icon_color: 'text-pink-600',
      chart_data_counts: @my_counts,
      chart_data_sums: @my_sums,
      # Sin controller (no AJAX reload)
      controller_name: nil %>
```

---

## 🚀 Futuras Mejoras (Roadmap)

### Corto Plazo

- [ ] Añadir opción para `stacked: true` (backward compatibility)
- [ ] Soporte para más de 3 sentimientos (escala granular)
- [ ] Export charts a PNG/SVG desde partial

### Mediano Plazo

- [ ] JavaScript component (Stimulus) para interactividad
- [ ] Animaciones al cargar gráficos
- [ ] Zoom/pan integrado

### Largo Plazo

- [ ] Librería NPM reutilizable
- [ ] Themes (dark mode, high contrast)
- [ ] A/B testing de visualizaciones

---

## 📚 Referencias Técnicas

### Arquitectura

```
app/
├── helpers/
│   └── sentiment_chart_helper.rb          # Helper con lógica
├── views/
│   └── shared/
│       └── _sentiment_trend_charts.html.erb  # Partial reutilizable
└── test/
    └── helpers/
        └── sentiment_chart_helper_test.rb  # Tests

Dashboards usando el partial:
- app/views/topic/show.html.erb
- app/views/tag/show.html.erb
```

### Dependencias

- **Chartkick**: Para renderizar gráficos
- **Highcharts**: Motor de gráficos JavaScript
- **Tailwind CSS**: Para estilos
- **ERB**: Templates

---

## ✅ Checklist de Implementación

- [x] Crear `SentimentChartHelper` con métodos reutilizables
- [x] Crear partial `_sentiment_trend_charts.html.erb`
- [x] Actualizar `topic/show.html.erb` para usar partial
- [x] Actualizar `tag/show.html.erb` para usar partial
- [x] Crear tests para helper
- [x] Documentación completa
- [x] Verificar no hay linter errors
- [x] Testing visual en navegador

---

## 🎓 Conclusiones

### Antes de la Refactorización

- ❌ Código duplicado (DRY violation)
- ❌ Difícil de mantener
- ❌ Area charts confusos
- ❌ Sin tests

### Después de la Refactorización

- ✅ DRY: Single source of truth
- ✅ Mantenible: Cambios centralizados
- ✅ Line charts claros y profesionales
- ✅ Testeado: 8 tests automáticos
- ✅ Extensible: Fácil añadir nuevos dashboards
- ✅ Consistente: Mismos colores y configuración

**Resultado**: Código más limpio, profesional y mantenible ✨

---

**Autor**: Cursor AI + Bruno Sacco
**Fecha**: Noviembre 8, 2025
**Versión**: 2.0 (Refactored with partials & helpers)

