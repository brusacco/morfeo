# PDF Reports - Professional Implementation Guide

## Quick Start: Apply Improvements to Existing Reports

This guide shows how to transform the current PDF reports into professional, CEO-ready documents using the new components created.

---

## Files Created

### 1. Helper Methods
**File:** `app/helpers/reports_helper.rb`

**Purpose:** Professional formatting, colors, and helper methods for reports

**Key Methods:**
- `format_metric_number(number)` - Format large numbers (1.5K, 2.3M)
- `trend_indicator(current, previous)` - Calculate and format trend arrows
- `sentiment_label(polarity)` - Get Spanish sentiment labels
- `sentiment_color(polarity)` - Get consistent sentiment colors
- `format_date_range(days)` - Format date ranges professionally

### 2. Professional CSS Styles
**File:** `app/views/shared/_pdf_professional_styles.html.erb`

**Purpose:** Complete CSS framework for executive-grade PDFs

**Features:**
- Professional typography with Google Fonts (Inter + Merriweather)
- Color palette with CSS variables
- Responsive metrics grids
- Executive summary styling
- Chart containers with proper spacing
- Word cloud improvements
- Print optimizations

### 3. Cover Page Partial
**File:** `app/views/shared/_pdf_cover_page.html.erb`

**Purpose:** Professional first page with branding

**Includes:**
- Company logo placeholder
- Report title
- Topic name in highlight box
- Date range
- Generation metadata
- Confidentiality notice

### 4. Executive Summary Partial
**File:** `app/views/shared/_pdf_executive_summary.html.erb`

**Purpose:** High-level overview for executives

**Includes:**
- Key metrics grid with trends
- Key findings bullets
- Main insights
- Professional color-coded icons

### 5. Grover Configuration
**File:** `config/initializers/grover.rb`

**Updates:**
- Larger margins (2.5cm top/bottom, 2cm sides)
- Professional font rendering
- Better timeout settings for chart rendering
- Quality optimizations

---

## Implementation Steps

### Step 1: Update Topic PDF Report

**File:** `app/views/topic/pdf.html.erb`

#### Add to `<head>` section:

```erb
<!-- Replace the inline <style> block with: -->
<%= render 'shared/pdf_professional_styles' %>
```

#### Add Cover Page (after `<body>` tag):

```erb
<%= render 'shared/pdf_cover_page', 
  report_type: 'Análisis de Medios Digitales',
  report_title: 'Informe de Tendencias y Sentimientos',
  topic_name: @topic.name,
  date_range: format_date_range(DAYS_RANGE),
  generated_date: Time.current.strftime("%d de %B de %Y, %H:%M"),
  prepared_for: 'Cliente Ejecutivo' # Optional: can pass client name from controller
%>
```

#### Add Executive Summary (after cover page):

```erb
<%
  # Calculate executive metrics
  total_entries = @entries.size
  total_interactions = @entries.sum(:total_count)
  avg_interactions = total_entries.zero? ? 0 : (total_interactions / total_entries).round
  
  positive_pct = @percentage_positives
  negative_pct = @percentage_negatives
  
  # Prepare key metrics
  key_metrics = [
    {
      icon: '📰',
      label: 'Total Noticias',
      value: format_metric_number(total_entries),
      color: '#1e40af'
    },
    {
      icon: '💬',
      label: 'Interacciones',
      value: format_metric_number(total_interactions),
      color: '#059669'
    },
    {
      icon: '📊',
      label: 'Promedio',
      value: format_metric_number(avg_interactions),
      color: '#d97706'
    },
    {
      icon: positive_pct >= negative_pct ? '😊' : '😐',
      label: 'Sentimiento',
      value: "#{positive_pct}% +",
      color: positive_pct >= negative_pct ? '#10b981' : '#6b7280'
    }
  ]
  
  # Prepare key findings
  sentiment_trend = if positive_pct > negative_pct
    { icon: '✓', color: '#059669', text: "El sentimiento general es positivo (#{positive_pct}% de menciones positivas)" }
  elsif negative_pct > positive_pct
    { icon: '✗', color: '#dc2626', text: "Se detectó un sentimiento negativo dominante (#{negative_pct}% de menciones negativas)" }
  else
    { icon: '→', color: '#6b7280', text: "El sentimiento es mayormente neutral (#{@percentage_neutrals}% de menciones)" }
  end
  
  top_site = @entries.group("sites.name").count('*').max_by { |_k, v| v }
  
  key_findings = [
    sentiment_trend,
    { 
      icon: '📈', 
      color: '#1e40af', 
      text: "Se registraron #{number_with_delimiter(total_entries, delimiter: '.')} menciones en los últimos #{DAYS_RANGE} días"
    }
  ]
  
  key_findings << {
    icon: '🏆',
    color: '#d97706',
    text: "El medio con más menciones fue #{top_site[0]} con #{top_site[1]} publicaciones"
  } if top_site
  
  # Prepare insights
  insights = []
  
  if avg_interactions > 100
    insights << "Alto nivel de engagement: cada nota genera en promedio #{avg_interactions} interacciones"
  end
  
  if @topic_percentage && @topic_percentage > 10
    insights << "El tópico representa el #{@topic_percentage}% de todas las noticias en el período analizado, indicando alta relevancia"
  end
  
  top_day = @chart_entries_counts.max_by { |_k, v| v }
  if top_day && top_day[1] > 5
    insights << "El día con mayor actividad fue #{top_day[0].strftime('%d/%m/%Y')} con #{top_day[1]} menciones"
  end
%>

<%= render 'shared/pdf_executive_summary',
  key_metrics: key_metrics,
  key_findings: key_findings,
  insights: insights.presence || []
%>
```

#### Remove auto-print (end of file):

```erb
<!-- REMOVE THIS: -->
<script>
  setTimeout(function() {
    window.print();
  }, 1000);
</script>

<!-- REPLACE WITH (optional): -->
<script>
  // Allow manual print via button or keyboard shortcut
  document.addEventListener('DOMContentLoaded', function() {
    console.log('PDF Report loaded. Press Ctrl+P to print.');
  });
</script>
```

---

### Step 2: Update Facebook Topic PDF Report

**File:** `app/views/facebook_topic/pdf.html.erb`

#### Same structure as Topic PDF:

1. Replace `<style>` with `<%= render 'shared/pdf_professional_styles' %>`
2. Add cover page partial (adapt metrics for Facebook)
3. Add executive summary with Facebook-specific metrics
4. Remove auto-print script

#### Facebook-specific metrics:

```erb
<%
  key_metrics = [
    {
      icon: '📘',
      label: 'Total Publicaciones',
      value: format_metric_number(@total_posts),
      color: '#3b82f6'
    },
    {
      icon: '❤️',
      label: 'Interacciones',
      value: format_metric_number(@total_interactions),
      color: '#ec4899'
    },
    {
      icon: '👁️',
      label: 'Vistas Estimadas',
      value: format_metric_number(@total_views),
      color: '#8b5cf6'
    },
    {
      icon: '📊',
      label: 'Promedio/Post',
      value: format_metric_number(@average_interactions),
      color: '#10b981'
    }
  ]
%>
```

---

### Step 3: Update Twitter Topic PDF Report

**File:** `app/views/twitter_topic/pdf.html.erb`

#### Same structure, Twitter-specific metrics:

```erb
<%
  key_metrics = [
    {
      icon: '🐦',
      label: 'Total Tweets',
      value: format_metric_number(@total_posts),
      color: '#0ea5e9'
    },
    {
      icon: '💙',
      label: 'Interacciones',
      value: format_metric_number(@total_interactions),
      color: '#3b82f6'
    },
    {
      icon: '👀',
      label: 'Vistas Totales',
      value: format_metric_number(@total_views),
      color: '#8b5cf6'
    },
    {
      icon: '📈',
      label: 'Promedio/Tweet',
      value: format_metric_number(@average_interactions),
      color: '#10b981'
    }
  ]
%>
```

---

### Step 4: Update Chart Colors for Consistency

In all three PDF files, update chart colors to use the professional palette:

#### Replace chart color arrays:

```erb
<!-- OLD: -->
colors: ['blue', 'green', 'red', 'yellow']

<!-- NEW: -->
colors: <%= ReportsHelper::CHART_COLORS.to_json %>
```

#### For sentiment charts:

```erb
<!-- OLD: -->
colors: ['red', 'lightgrey', 'lightgreen']

<!-- NEW: -->
colors: ['#ef4444', '#9ca3af', '#10b981']
```

---

### Step 5: Improve Section Headers

Replace existing section headers with better formatting:

```erb
<!-- OLD: -->
<h2>Análisis de Sentimiento</h2>

<!-- NEW: -->
<h2 class="section-header">Análisis de Sentimiento</h2>
```

---

### Step 6: Add Insights Boxes

After key charts, add insight boxes:

```erb
<!-- After sentiment charts -->
<div class="pdf-insights-box">
  <div class="pdf-insights-title">Insights Clave</div>
  <ul class="pdf-insights-list">
    <li>
      El sentimiento positivo representa el <%= @percentage_positives %>% del total de menciones
    </li>
    <li>
      Se observa una tendencia <%= @positives > @negatives ? 'favorable' : 'a monitorear' %> en la percepción del tópico
    </li>
    <% if @most_interactions.first %>
      <li>
        La noticia con mayor impacto generó <%= number_with_delimiter(@most_interactions.first.total_count, delimiter: '.') %> interacciones
      </li>
    <% end %>
  </ul>
</div>
```

---

### Step 7: Improve KPI Cards

Replace basic stats cards with enhanced versions:

```erb
<!-- OLD: -->
<div class="pdf-stats-card">
  <div class="pdf-stats-label">Total Noticias</div>
  <div class="pdf-stats-value"><%= number_with_delimiter(@entries.size, delimiter: ".") %></div>
</div>

<!-- NEW: (using new classes) -->
<div class="pdf-metric-card">
  <div class="pdf-metric-icon">📰</div>
  <div class="pdf-metric-label">Total Noticias</div>
  <div class="pdf-metric-value-container">
    <span class="pdf-metric-value"><%= format_metric_number(@entries.size) %></span>
  </div>
</div>
```

---

## Controller Updates (Optional but Recommended)

### Add Previous Period Data for Trends

**File:** `app/controllers/topic_controller.rb`

Add to `load_topic_data` method:

```ruby
def load_topic_data
  # ... existing code ...
  
  # Calculate previous period for trends
  @previous_period_start = (DAYS_RANGE * 2).days.ago
  @previous_period_end = DAYS_RANGE.days.ago
  
  @previous_entries = @topic.list_entries
    .where('published_at >= ? AND published_at < ?', @previous_period_start, @previous_period_end)
  
  @previous_entries_count = @previous_entries.size
  @previous_total_interactions = @previous_entries.sum(:total_count)
end
```

Then in views, add trends:

```erb
<%
  trend = trend_indicator(@entries_count, @previous_entries_count)
%>

<%= metric_card(
  'Total Noticias',
  format_metric_number(@entries_count),
  trend: trend,
  icon: '📰'
) %>
```

---

## Testing Checklist

- [ ] Cover page displays correctly with all metadata
- [ ] Executive summary shows accurate metrics
- [ ] Typography renders with professional fonts (Inter/Merriweather)
- [ ] Colors are consistent across all charts
- [ ] Page breaks work correctly (sections don't split awkwardly)
- [ ] Charts render completely before PDF generation
- [ ] Word clouds are legible and professional
- [ ] Print quality is high (test actual print, not just preview)
- [ ] All trend indicators calculate correctly
- [ ] Insights are relevant and accurate
- [ ] No auto-print interference
- [ ] PDF file size is reasonable (< 5MB for typical report)

---

## Advanced Customizations

### 1. Add Client Logo

In controller:

```ruby
def pdf
  # ... existing code ...
  @client_logo_path = @topic.client&.logo_url || asset_path('default_client_logo.png')
end
```

In cover page:

```erb
<%= render 'shared/pdf_cover_page',
  logo_path: @client_logo_path,
  # ... other params ...
%>
```

### 2. Custom Color Schemes per Client

In `Topic` model:

```ruby
def brand_color
  client&.primary_color || '#1e40af'
end
```

In view:

```erb
<style>
  :root {
    --color-primary: <%= @topic.brand_color %>;
  }
</style>
```

### 3. Conditional Sections

Hide word cloud if insufficient data:

```erb
<% if @word_occurrences.size >= 10 %>
  <!-- Word cloud section -->
<% else %>
  <div class="pdf-no-data">
    Datos insuficientes para generar nube de palabras
  </div>
<% end %>
```

### 4. Methodology Appendix

Add at end of report:

```erb
<div class="pdf-section break-before">
  <h2>Metodología y Fuentes</h2>
  
  <h3>Fuentes de Datos</h3>
  <ul>
    <li>Medios digitales monitoreados: <%= @entries.joins(:site).distinct.count(:site_id) %></li>
    <li>Período de análisis: <%= format_date_range(DAYS_RANGE) %></li>
    <li>Total de menciones analizadas: <%= number_with_delimiter(@entries.size, delimiter: '.') %></li>
  </ul>
  
  <h3>Análisis de Sentimiento</h3>
  <p>
    El análisis de sentimiento se realiza mediante algoritmos de procesamiento de lenguaje natural (NLP)
    que clasifican cada mención como positiva, negativa o neutral basándose en el contenido del texto.
  </p>
  
  <h3>Cálculo de Interacciones</h3>
  <p>
    Las interacciones incluyen la suma de reacciones, comentarios y compartidos para cada publicación.
    El promedio se calcula dividiendo el total de interacciones por el número de menciones.
  </p>
  
  <div style="margin-top: 24pt; padding-top: 16pt; border-top: 1pt solid #e5e7eb; font-size: 8pt; color: #6b7280;">
    <strong>Contacto:</strong> analytics@morfeo.com | 
    <strong>Generado:</strong> <%= Time.current.strftime("%d/%m/%Y %H:%M:%S") %> |
    <strong>Versión:</strong> 2.0
  </div>
</div>
```

---

## Troubleshooting

### Charts not rendering in PDF

**Solution:** Increase Grover timeout and ensure `wait_until: 'networkidle0'`

```ruby
# config/initializers/grover.rb
config.options = {
  timeout: 90000,
  wait_until: 'networkidle0'
}
```

### Fonts not loading

**Solution:** Use web-safe fallback fonts

```css
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
}
```

### Page breaks in wrong places

**Solution:** Use `page-break-inside: avoid` more aggressively

```erb
<div class="pdf-section" style="page-break-inside: avoid;">
  <!-- content -->
</div>
```

### Colors not printing

**Solution:** Verify print color settings

```css
@media print {
  body {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
}
```

---

## Performance Tips

1. **Cache expensive calculations** in controller
2. **Limit word occurrences** to top 100 (not 1000)
3. **Optimize chart data** - pre-aggregate in database
4. **Use CDN for fonts** - faster loading
5. **Lazy load charts** - render on-demand

---

## Future Enhancements

- [ ] Add table of contents with page numbers
- [ ] Include comparative analysis (vs previous periods)
- [ ] Add industry benchmarks
- [ ] Create downloadable data appendix (CSV)
- [ ] Implement multi-language support
- [ ] Add interactive PDF features (links, bookmarks)
- [ ] Create template variations (standard, premium, executive)
- [ ] Add watermark for draft versions
- [ ] Include QR code for digital version access

---

## Support & Documentation

- **Main Guide:** `PDF_REPORTS_IMPROVEMENT_PLAN.md`
- **Helper Methods:** `app/helpers/reports_helper.rb` (documented inline)
- **CSS Framework:** `app/views/shared/_pdf_professional_styles.html.erb` (commented)
- **Example Reports:** See updated PDF views in `app/views/*/pdf.html.erb`

---

**Version:** 2.0  
**Last Updated:** October 30, 2025  
**Author:** Senior UI/UX Designer

