# ChartsHelper Usage Guide

## 📊 Overview

The `ChartsHelper` module provides a consistent, DRY way to render charts across all dashboards in the Morfeo application.

---

## 🎨 Configuration

All chart colors and defaults are configured in `config/initializers/chart_config.rb`:

```ruby
CHART_CONFIG = {
  colors: {
    primary: '#3B82F6',    # blue-500
    success: '#10B981',    # green-500
    purple: '#8B5CF6',     # purple-500
    warning: '#F59E0B',    # amber-500
    danger: '#EF4444',     # red-500
    # ... more colors
  }
}
```

---

## 📖 Usage Examples

### Basic Column Chart (Clickable)

```erb
<%= render_column_chart(@chart_posts,
      chart_id: 'facebookPostsChart',
      url: entries_data_facebook_topics_path,
      topic_id: @topic.id,
      label: 'Publicaciones',
      color: :primary,
      xtitle: 'Fecha',
      ytitle: 'Publicaciones') %>
```

**Result:**
- Blue column chart
- Tooltip shows "15 Publicaciones"
- Clickable bars open modal with entries
- Consistent styling

---

### Area Chart (Stacked, Multiple Colors)

```erb
<%= render_area_chart(
      polarity_stacked_chart_data(@chart_entries_sentiments_sums),
      chart_id: 'sentimentChart',
      url: entries_data_topics_path,
      topic_id: @topic.id,
      stacked: true,
      colors: [:success, :gray, :danger],
      xtitle: 'Fecha',
      ytitle: 'Cantidad') %>
```

**Result:**
- Stacked area chart
- Green (positive), Gray (neutral), Red (negative)
- Clickable with sentiment filtering

---

### Pie Chart (Non-clickable)

```erb
<%= render_pie_chart(@sentiment_distribution,
      donut: true,
      suffix: '%') %>
```

**Result:**
- Donut chart
- Values show as "25%"
- Not clickable (no modal)

---

## 🔧 Method Reference

### `render_column_chart(data, **options)`

Renders a clickable column chart.

**Parameters:**
- `data` (Hash): Chart data from groupdate or manual hash
- `options` (Hash): Configuration options

**Options:**
| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `:chart_id` | String | Yes* | nil | Unique chart ID (*required for clickable) |
| `:url` | String | Yes* | nil | URL to load entries (*required for clickable) |
| `:topic_id` | Integer | Yes* | nil | Topic ID for filtering (*required for clickable) |
| `:label` | String | Yes | nil | Label for tooltip (e.g., "Publicaciones") |
| `:color` | Symbol | No | `:primary` | Color key from CHART_CONFIG |
| `:xtitle` | String | No | nil | X-axis title |
| `:ytitle` | String | No | nil | Y-axis title |
| `:title` | Boolean | No | `false` | Title-based filtering flag |
| `:clickable` | Boolean | No | `true` | Enable click events |
| `:library` | Hash | No | `{}` | Custom Highcharts config |

---

### `render_area_chart(data, **options)`

Renders a clickable area chart with optional stacking.

**Additional Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `:stacked` | Boolean | `false` | Enable stacking |
| `:colors` | Array | `[:primary]` | Array of color keys for series |

**Example:**
```erb
<%= render_area_chart(@data,
      chart_id: 'myChart',
      url: my_path,
      topic_id: @topic.id,
      stacked: true,
      colors: [:success, :warning, :danger]) %>
```

---

### `render_pie_chart(data, **options)`

Renders a non-clickable pie or donut chart.

**Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `:donut` | Boolean | `false` | Render as donut chart |
| `:suffix` | String | `''` | Suffix for values (e.g., '%') |

---

### Helper Methods

#### `chart_color(color_key)`

Get a single color hex code.

```ruby
chart_color(:success)  # => "#10B981"
```

#### `chart_colors(*color_keys)`

Get multiple color hex codes.

```ruby
chart_colors(:success, :warning, :danger)
# => ["#10B981", "#F59E0B", "#EF4444"]
```

#### `sentiment_chart_config`

Get pre-configured settings for sentiment charts.

```ruby
<%= area_chart @sentiment_data, 
      library: sentiment_chart_config %>
```

---

## 🔄 Migration Guide

### Before (Old Way)

```erb
<div class="w-full overflow-hidden"
     data-controller="topics"
     data-topics-id-value="facebookPostsChart"
     data-topics-url-value="<%= entries_data_facebook_topics_path %>"
     data-topics-topic-id-value="<%= @topic.id %>"
     data-topics-title-value="false">
  <%= column_chart @chart_posts, 
        xtitle: 'Fecha', 
        ytitle: 'Publicaciones',
        id: 'facebookPostsChart', 
        adapter: 'highcharts', 
        colors: ['#3B82F6'], 
        thousands: '.',
        library: { 
          plotOptions: { 
            series: { 
              dataLabels: { enabled: true }
            } 
          },
          tooltip: {
            pointFormat: '<b>{point.y}</b> Publicaciones'
          }
        } %>
  <%= render 'home/modal', graph_id: 'facebookPostsChart', controller_name: 'topics' %>
</div>
```

### After (New Way)

```erb
<%= render_column_chart(@chart_posts,
      chart_id: 'facebookPostsChart',
      url: entries_data_facebook_topics_path,
      topic_id: @topic.id,
      label: 'Publicaciones',
      color: :primary,
      xtitle: 'Fecha',
      ytitle: 'Publicaciones') %>
```

**Lines of code:** 27 → 7 (74% reduction)

---

## 🎯 Migration Checklist

For each dashboard view:

- [ ] Replace column charts with `render_column_chart`
- [ ] Replace area charts with `render_area_chart`
- [ ] Replace pie charts with `render_pie_chart`
- [ ] Remove wrapper divs (now handled by helper)
- [ ] Remove manual modal renders (now handled by helper)
- [ ] Test clickable functionality
- [ ] Verify tooltip labels
- [ ] Check color consistency

---

## 🔍 Common Patterns

### Pattern 1: Posts/Mentions Chart

```erb
<%= render_column_chart(@chart_posts,
      chart_id: 'postsChart',
      url: entries_data_path,
      topic_id: @topic.id,
      label: 'Publicaciones',
      color: :primary,
      xtitle: 'Fecha',
      ytitle: 'Cantidad') %>
```

### Pattern 2: Interactions Chart

```erb
<%= render_column_chart(@chart_interactions,
      chart_id: 'interactionsChart',
      url: entries_data_path,
      topic_id: @topic.id,
      label: 'Interacciones',
      color: :success,
      xtitle: 'Fecha',
      ytitle: 'Total') %>
```

### Pattern 3: Sentiment Stacked Chart

```erb
<%= render_area_chart(
      polarity_stacked_chart_data(@sentiment_data),
      chart_id: 'sentimentChart',
      url: entries_data_path,
      topic_id: @topic.id,
      stacked: true,
      colors: [:success, :gray, :danger],
      xtitle: 'Fecha',
      ytitle: 'Cantidad') %>
```

### Pattern 4: Distribution Pie Chart

```erb
<%= render_pie_chart(@distribution_data,
      donut: true,
      suffix: '%') %>
```

---

## 🧪 Testing

Test chart helper methods:

```ruby
# test/helpers/charts_helper_test.rb
require 'test_helper'

class ChartsHelperTest < ActionView::TestCase
  test "chart_color returns correct hex code" do
    assert_equal '#3B82F6', chart_color(:primary)
    assert_equal '#10B981', chart_color(:success)
  end

  test "chart_colors returns array of hex codes" do
    colors = chart_colors(:success, :danger)
    assert_equal ['#10B981', '#EF4444'], colors
  end

  test "build_chart_options includes required fields" do
    # Test implementation
  end
end
```

---

## 📝 Notes

### Color Usage Guidelines

- **Primary (Blue)**: Default for neutral metrics
- **Success (Green)**: Positive metrics, growth
- **Warning (Amber)**: Alerts, important metrics
- **Danger (Red)**: Negative metrics, declines
- **Purple**: Special emphasis, featured content
- **Indigo**: User actions, engagement

### Performance Considerations

- All charts use the same base configuration (cached)
- Data attributes only added when needed (clickable charts)
- Highcharts library loaded once per page

### Accessibility

Future enhancement: Add ARIA labels and roles

```erb
# Future implementation
<%= render_column_chart(@data,
      aria_label: 'Gráfico de publicaciones por día',
      ...) %>
```

---

## 🐛 Troubleshooting

### Issue: Tooltip shows "undefined"

**Solution:** Make sure `label` option is provided:

```erb
<%= render_column_chart(@data,
      label: 'Publicaciones',  # Required for tooltip
      ...) %>
```

### Issue: Chart not clickable

**Solution:** Ensure all required options are provided:

```erb
<%= render_column_chart(@data,
      chart_id: 'myChart',     # Required
      url: my_path,             # Required
      topic_id: @topic.id,      # Required
      ...) %>
```

### Issue: Wrong color

**Solution:** Check color key exists in CHART_CONFIG:

```ruby
# config/initializers/chart_config.rb
CHART_CONFIG = {
  colors: {
    my_color: '#HEXCODE'  # Add custom color
  }
}
```

---

## 📚 Additional Resources

- [Chartkick Documentation](https://chartkick.com/)
- [Highcharts API Reference](https://api.highcharts.com/highcharts/)
- [Tailwind CSS Colors](https://tailwindcss.com/docs/customizing-colors)

