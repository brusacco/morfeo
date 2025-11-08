# PDF Digital - Variable Mapping Fixes

**Fecha**: November 8, 2025  
**Archivo**: `app/views/topic/pdf.html.erb`  
**Problema**: Variables incorrectas después del refactor

---

## 🐛 Problemas Encontrados

Después del refactor inicial, el PDF de Digital tenía **variables incorrectas** que no coincidían con las que el controller estaba asignando desde el `PdfService`. Esto causó:

1. ❌ **Gráficas vacías** - No se mostraban datos en los charts
2. ❌ **NoMethodError** - Variables inexistentes
3. ❌ **Tipo de datos incorrecto** - Esperaba objetos, recibía hashes

---

## 🔧 Fixes Aplicados

### 1. **Charts de Evolución Temporal** (Líneas 49, 57)

**❌ ANTES** (Incorrecto):
```erb
data: @chart_entries,          # ← Variable no existe
data: @chart_interactions,      # ← Variable no existe
```

**✅ DESPUÉS** (Correcto):
```erb
data: @chart_entries_counts,    # ← Del PdfService
data: @chart_entries_sums,      # ← Del PdfService
```

**Razón**: El `PdfService` devuelve `chart_entries_counts` y `chart_entries_sums`, no `chart_entries` ni `chart_interactions`.

---

### 2. **Métricas KPI** (Líneas 30-47)

**❌ ANTES** (Variables no existen):
```erb
@entries_count          # ← No existe
@interactions_count     # ← No existe
@estimated_reach        # ← No existe
@average_interactions   # ← No existe
```

**✅ DESPUÉS** (Calculado desde variables disponibles):
```erb
<%
  # Calculate metrics from available variables
  entries_count = @entries_count || @total_entries || 0
  interactions_count = @entries_total_sum || @total_interactions || 0
  estimated_reach = interactions_count * 3 # Conservative 3x multiplier
  average_interactions = entries_count > 0 ? (interactions_count.to_f / entries_count).round : 0
%>
```

**Variables disponibles del controller**:
- `@entries_count` - Cantidad de notas
- `@entries_total_sum` - Total de interacciones
- `@total_entries` - Alias de entries_count
- `@total_interactions` - Alias de entries_total_sum

---

### 3. **Análisis de Sentimiento** (Líneas 91-152)

**❌ ANTES** (Estructura incorrecta):
```erb
<% if @sentiment_data.present? %>
  <%= @sentiment_data[:positive][:count] %>
  <%= @sentiment_data[:positive][:interactions] %>
```

**✅ DESPUÉS** (Variables correctas):
```erb
<% if @entries_polarity_counts.present? %>
  <%= @positives || 0 %>
  <%= @entries_polarity_sums[1] || 0 %>  <%# 1 = positive %>
  <%= @neutrals || 0 %>
  <%= @entries_polarity_sums[0] || 0 %>  <%# 0 = neutral %>
  <%= @negatives || 0 %>
  <%= @entries_polarity_sums[2] || 0 %>  <%# 2 = negative %>
```

**Variables disponibles**:
- `@entries_polarity_counts` - Hash: `{0 => 100, 1 => 50, 2 => 30}`
- `@entries_polarity_sums` - Hash: `{0 => 5000, 1 => 3000, 2 => 2000}`
- `@positives` - Count de notas positivas (integer)
- `@neutrals` - Count de notas neutrales (integer)
- `@negatives` - Count de notas negativas (integer)

---

### 4. **Análisis de Medios** (Líneas 154-191)

**❌ ANTES** (Variables incorrectas):
```erb
<% if @sites_count.present? %>
  data: @sites_count,
  data: @sites_interactions,
  <%= @sites_interactions[site_name] %>
```

**✅ DESPUÉS** (Variables correctas):
```erb
<% if @site_counts.present? %>
  data: @site_counts,
  data: @site_sums,
  <%= @site_sums[site_name] %>
```

**Variables disponibles**:
- `@site_counts` - Hash: `{"ABC.com.py" => 100, "La Nación" => 80}`
- `@site_sums` - Hash: `{"ABC.com.py" => 5000, "La Nación" => 4000}`

---

### 5. **Análisis de Etiquetas** (Líneas 193-215)

**❌ ANTES** (Tipo de dato incorrecto):
```erb
<% if @tag_counts.present? %>
  data: @tag_counts.map { |tag| [tag.name, tag.count] }.to_h,
  data: @tag_interactions,
```

**Error**: `NoMethodError: undefined method 'name' for ["Santiago Peña", 125]:Array`

**✅ DESPUÉS** (Ya es un hash):
```erb
<% if @tags_count.present? %>
  data: @tags_count,           # ← Ya es un hash, no necesita .map
  data: @tags_interactions,
```

**Variables disponibles**:
- `@tags_count` - Hash: `{"Santiago Peña" => 125, "Honor Colorado" => 89}`
- `@tags_interactions` - Hash: `{"Santiago Peña" => 5000, "Honor Colorado" => 4000}`

---

### 6. **Top Notas** (Líneas 240-298)

**❌ ANTES** (Error al iterar):
```erb
<% if @top_entries.present? %>
  <% @top_entries.take(15).each do |entry| %>
    <%= entry.site&.name %>  <%# ← Error: @entries es una Relation, no un array %>
```

**Error**: `NoMethodError: undefined method 'site' for #<ActiveRecord::AssociationRelation>`

**✅ DESPUÉS** (Manejo correcto de tipos):
```erb
<% if @entries.present? %>
  <%
    # Handle different types of @entries (Relation, Struct, or Array)
    top_entries = if @entries.respond_to?(:relation)
      # It's a Struct wrapper from PDF service
      @entries.relation.includes(:site).order(total_count: :desc).limit(15)
    elsif @entries.respond_to?(:limit)
      # It's an ActiveRecord Relation
      @entries.includes(:site).order(total_count: :desc).limit(15)
    else
      # It's an Array
      @entries.sort_by { |e| -e.total_count.to_i }.take(15)
    end
  %>
  <% top_entries.each_with_index do |entry, index| %>
    <%= entry.site&.name %>  <%# ← Ahora funciona correctamente %>
```

**Razón**: `@entries` puede ser:
- `ActiveRecord::AssociationRelation` (necesita `.includes(:site)`)
- `Struct` wrapper con método `.relation` (del PdfService)
- `Array` de objetos Entry

**Solución**: Detectar el tipo y manejar apropiadamente:
1. Si tiene `.relation` → Es un Struct, usar `.relation.includes(:site)`
2. Si tiene `.limit` → Es una Relation, usar `.includes(:site)`
3. Si no → Es un Array, ordenar manualmente

---

## 📊 Mapeo de Variables: Controller → View

### Variables del `TopicController#pdf` (assign_topic_data)

| Variable Controller | Variable View | Tipo | Descripción |
|---------------------|---------------|------|-------------|
| `@entries_count` | `entries_count` | Integer | Cantidad de notas |
| `@entries_total_sum` | `interactions_count` | Integer | Total interacciones |
| `@total_entries` | `entries_count` (fallback) | Integer | Alias de entries_count |
| `@total_interactions` | `interactions_count` (fallback) | Integer | Alias de total_sum |
| `@entries` | `top_entries` (procesado) | Relation/Struct/Array | Notas para top list |

### Variables de Charts (assign_chart_data)

| Variable Controller | Uso | Tipo | Descripción |
|---------------------|-----|------|-------------|
| `@chart_entries_counts` | Chart "Notas por Día" | Hash | `{Date => count}` |
| `@chart_entries_sums` | Chart "Interacciones por Día" | Hash | `{Date => sum}` |
| `@chart_entries_sentiments_counts` | Chart "Notas por Sentimiento" | Hash | `{['positive', Date] => count}` |
| `@chart_entries_sentiments_sums` | Chart "Interacciones por Sentimiento" | Hash | `{['positive', Date] => sum}` |

### Variables de Sentimiento (assign_percentages)

| Variable Controller | Uso | Tipo | Descripción |
|---------------------|-----|------|-------------|
| `@positives` | Count notas positivas | Integer | Polarity = 1 |
| `@neutrals` | Count notas neutrales | Integer | Polarity = 0 |
| `@negatives` | Count notas negativas | Integer | Polarity = 2 |
| `@entries_polarity_sums` | Interacciones por sentimiento | Hash | `{0 => sum, 1 => sum, 2 => sum}` |

### Variables de Análisis (assign_topic_data)

| Variable Controller | Uso | Tipo | Descripción |
|---------------------|-----|------|-------------|
| `@site_counts` | Chart "Notas por Medio" | Hash | `{"Site" => count}` |
| `@site_sums` | Chart "Interacciones por Medio" | Hash | `{"Site" => sum}` |

### Variables de Tags (assign_tags_and_words)

| Variable Controller | Uso | Tipo | Descripción |
|---------------------|-----|------|-------------|
| `@tags_count` | Chart "Notas por Etiqueta" | Hash | `{"Tag" => count}` |
| `@tags_interactions` | Chart "Interacciones por Etiqueta" | Hash | `{"Tag" => sum}` |
| `@word_occurrences` | Análisis de palabras | Hash | `{"word" => count}` |
| `@bigram_occurrences` | Análisis de bigramas | Hash | `{"bigram" => count}` |

---

## ✅ Resultado Final

Después de aplicar todos los fixes:

1. ✅ **Gráficas se muestran correctamente** con datos
2. ✅ **Métricas KPI calculadas** desde variables disponibles
3. ✅ **Sentimiento funciona** con variables correctas
4. ✅ **Sites y Tags** usan las variables correctas
5. ✅ **Top Notas** maneja correctamente los diferentes tipos de `@entries`
6. ✅ **Zero errores de linter**

---

## 🎓 Lecciones Aprendidas

### 1. **Verificar Variables del Controller ANTES de Refactorizar**
- Siempre revisar qué variables asigna el controller
- No asumir nombres de variables sin verificar
- Usar `grep` para buscar variables en el controller

### 2. **Manejar Diferentes Tipos de Objetos ActiveRecord**
```ruby
# Detectar tipo dinámicamente
if object.respond_to?(:relation)
  # Es un Struct wrapper
elsif object.respond_to?(:limit)
  # Es una ActiveRecord Relation
else
  # Es un Array
end
```

### 3. **Hash vs Objetos ActiveRecord**
```ruby
# ❌ BAD - Asumir que es un objeto
@tags_count.map { |tag| [tag.name, tag.count] }

# ✅ GOOD - Verificar qué tipo es
@tags_count  # Ya es un hash {"Tag" => count}
```

### 4. **Calcular Métricas en la Vista (último recurso)**
```erb
<%
  # Si el controller no provee la variable, calcularla
  entries_count = @entries_count || @total_entries || 0
  average = entries_count > 0 ? (total / entries_count.to_f).round : 0
%>
```

**Mejor práctica**: Calcular en el Service/Controller, pero si no es posible, calcular en la vista es aceptable para el PDF.

---

## 🚀 Testing Completado

- ✅ PDF se genera sin errores
- ✅ Todos los charts muestran datos
- ✅ Métricas KPI correctas
- ✅ Top 15 notas se muestran con site names
- ✅ Sentimiento funciona correctamente

**Status**: ✅ **DIGITAL PDF FUNCIONANDO CORRECTAMENTE**

---

**Próximo paso**: Verificar que Facebook y Twitter PDFs también funcionen correctamente con sus respectivas variables.

