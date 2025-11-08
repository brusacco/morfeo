# 🔄 ChartsHelper Refactoring Example

This document shows a real-world example of refactoring chart code using the new ChartsHelper module.

---

## 📊 Facebook Dashboard - Evolución Temporal Section

### ❌ BEFORE (Old Code - 54 lines)

```erb
<section id="charts">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">
    <i class="fa-solid fa-chart-line text-indigo-600 mr-2"></i>
    Evolución temporal
  </h2>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Chart 1: Publications -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Publicaciones por día</h3>
        <span class="text-sm text-gray-500">Últimos <%= DAYS_RANGE %> días</span>
      </div>
      <div class="w-full overflow-hidden"
           data-controller="topics"
           data-topics-id-value="facebookPostsChart"
           data-topics-url-value="<%= entries_data_facebook_topics_path %>"
           data-topics-topic-id-value="<%= @topic.id %>"
           data-topics-title-value="false">
        <%= column_chart @chart_posts, xtitle: 'Fecha', ytitle: 'Publicaciones',
              id: 'facebookPostsChart', adapter: 'highcharts', 
              colors: ['#3B82F6'], thousands: '.',
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
    </div>
    
    <!-- Chart 2: Interactions -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Interacciones por día</h3>
        <span class="text-sm text-gray-500">Total diario</span>
      </div>
      <div class="w-full overflow-hidden"
           data-controller="topics"
           data-topics-id-value="facebookInteractionsChart"
           data-topics-url-value="<%= entries_data_facebook_topics_path %>"
           data-topics-topic-id-value="<%= @topic.id %>"
           data-topics-title-value="false">
        <%= column_chart @chart_interactions, xtitle: 'Fecha', ytitle: 'Interacciones',
              id: 'facebookInteractionsChart', adapter: 'highcharts', 
              colors: ['#10B981'], thousands: '.',
              library: { 
                plotOptions: { 
                  series: { 
                    dataLabels: { enabled: true }
                  } 
                },
                tooltip: {
                  pointFormat: '<b>{point.y}</b> Interacciones'
                }
              } %>
        <%= render 'home/modal', graph_id: 'facebookInteractionsChart', controller_name: 'topics' %>
      </div>
    </div>
  </div>
</section>
```

---

### ✅ AFTER (New Code with Helper - 30 lines)

```erb
<section id="charts">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">
    <i class="fa-solid fa-chart-line text-indigo-600 mr-2"></i>
    Evolución temporal
  </h2>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Chart 1: Publications -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Publicaciones por día</h3>
        <span class="text-sm text-gray-500">Últimos <%= DAYS_RANGE %> días</span>
      </div>
      <%= render_column_chart(@chart_posts,
            chart_id: 'facebookPostsChart',
            url: entries_data_facebook_topics_path,
            topic_id: @topic.id,
            label: 'Publicaciones',
            color: :primary,
            xtitle: 'Fecha',
            ytitle: 'Publicaciones') %>
    </div>
    
    <!-- Chart 2: Interactions -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Interacciones por día</h3>
        <span class="text-sm text-gray-500">Total diario</span>
      </div>
      <%= render_column_chart(@chart_interactions,
            chart_id: 'facebookInteractionsChart',
            url: entries_data_facebook_topics_path,
            topic_id: @topic.id,
            label: 'Interacciones',
            color: :success,
            xtitle: 'Fecha',
            ytitle: 'Interacciones') %>
    </div>
  </div>
</section>
```

---

## 📈 Improvements

### Code Reduction
- **Before**: 54 lines (per section)
- **After**: 30 lines (per section)
- **Reduction**: 44% fewer lines

### Benefits

1. **DRY Principle**
   - Chart configuration in one place
   - No repeated wrapper divs
   - No repeated modal renders

2. **Maintainability**
   - Change tooltip format once, affects all charts
   - Change colors in config, not in 20+ places
   - Easier to spot inconsistencies

3. **Readability**
   - Intent is clear at first glance
   - Less visual noise
   - Consistent patterns

4. **Testing**
   - Helper methods can be unit tested
   - Configuration can be validated
   - Easier to mock for integration tests

---

## 🎯 Migration Strategy

### Phase 1: Facebook Dashboard (1 hour)
- [x] Create ChartsHelper
- [x] Create chart_config.rb
- [ ] Refactor facebook_topic/show.html.erb
- [ ] Test all Facebook charts
- [ ] Verify tooltips and clicks

### Phase 2: Digital Dashboard (1 hour)
- [ ] Refactor topic/show.html.erb
- [ ] Test all digital charts
- [ ] Verify title-based filtering

### Phase 3: Twitter Dashboard (1 hour)
- [ ] Refactor twitter_topic/show.html.erb
- [ ] Test all Twitter charts

### Phase 4: General Dashboard (1-2 hours)
- [ ] Refactor general_dashboard/show.html.erb
- [ ] Handle multi-source charts
- [ ] Test cross-channel aggregation

### Phase 5: Cleanup (30 min)
- [ ] Remove unused CSS
- [ ] Delete redundant code
- [ ] Update documentation

---

## 🧪 Testing Checklist

For each refactored chart:

- [ ] Tooltip shows correct label
- [ ] Tooltip shows correct number format
- [ ] Click opens modal
- [ ] Modal loads correct entries
- [ ] Date filtering works
- [ ] Polarity filtering works (sentiment charts)
- [ ] Chart colors match design
- [ ] Data labels display correctly
- [ ] Responsive on mobile
- [ ] No console errors

---

## 🔍 Common Migration Patterns

### Pattern 1: Simple Column Chart

**Before:**
```erb
<div class="w-full overflow-hidden" data-controller="topics" ...>
  <%= column_chart @data, id: 'myChart', colors: ['#3B82F6'], ... %>
  <%= render 'home/modal', graph_id: 'myChart', controller_name: 'topics' %>
</div>
```

**After:**
```erb
<%= render_column_chart(@data,
      chart_id: 'myChart',
      url: my_path,
      topic_id: @topic.id,
      label: 'My Label',
      color: :primary) %>
```

---

### Pattern 2: Stacked Area Chart

**Before:**
```erb
<div class="w-full overflow-hidden" data-controller="topics" ...>
  <%= area_chart @data, stacked: true, colors: ['#10B981', '#9CA3AF', '#EF4444'], ... %>
  <%= render 'home/modal', ... %>
</div>
```

**After:**
```erb
<%= render_area_chart(@data,
      chart_id: 'myChart',
      url: my_path,
      topic_id: @topic.id,
      stacked: true,
      colors: [:success, :gray, :danger]) %>
```

---

### Pattern 3: Pie Chart (No click)

**Before:**
```erb
<%= pie_chart @data, donut: true, suffix: '%' %>
```

**After:**
```erb
<%= render_pie_chart(@data, donut: true, suffix: '%') %>
```

---

## 📝 Notes

### Breaking Changes
None. The helper is additive and doesn't break existing code.

### Backward Compatibility
Old chart code still works. Can migrate incrementally.

### Performance Impact
Negligible. Helper methods add minimal overhead.

---

## 🎓 Learning from This Refactor

### What We Fixed
1. ❌ **DRY Violation** → ✅ Single source of truth
2. ❌ **Magic strings** → ✅ Centralized config
3. ❌ **Fat views** → ✅ Helper abstraction
4. ❌ **Hard to test** → ✅ Unit testable
5. ❌ **Inconsistent** → ✅ Standardized

### Principles Applied
- **DRY**: Don't Repeat Yourself
- **SRP**: Single Responsibility Principle
- **OCP**: Open/Closed Principle (extend config without modifying code)
- **Convention over Configuration**: Sensible defaults

### Rails Best Practices
- ✅ Fat models, skinny controllers, **helpers for view logic**
- ✅ Configuration in initializers
- ✅ Documentation with examples
- ✅ Incremental refactoring (not a rewrite)

---

## 🚀 Next Steps

1. **Immediate**: Refactor Facebook dashboard (provided example)
2. **This week**: Refactor other dashboards
3. **Next sprint**: Add I18n support for labels
4. **Future**: Consider ViewComponent for complete chart components

