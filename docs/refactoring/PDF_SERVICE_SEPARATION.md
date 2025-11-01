# PDF Service Separation

## Overview

Separated PDF generation logic into a dedicated service to maintain clean separation of concerns and handle PDF-specific calculations independently from the regular dashboard view.

**Date**: November 1, 2025  
**Affected Area**: Digital Topic Dashboard (Topic Controller)

---

## Problem

After refactoring the topic controller to use `DigitalDashboardServices::AggregatorService`, PDF generation had different requirements:

1. **Different percentage calculations**: PDF excludes current topic entries for "share of voice" perspective
2. **Different data needs**: PDF requires `@title_chart_entries` relation for chart generation
3. **Mixed concerns**: Dashboard service was handling both regular view and PDF-specific logic

---

## Solution

Created a dedicated `DigitalDashboardServices::PdfService` that handles all PDF-specific data loading and calculations.

---

## Changes Made

### 1. New Service: `PdfService`

**File**: `app/services/digital_dashboard_services/pdf_service.rb`

**Responsibilities**:
- Load topic data for PDF
- Load chart data with `title_chart_entries` relation
- Calculate PDF-specific percentages (excluding topic entries)
- Provide word and bigram analysis
- Handle tags analysis

**Key Differences from Dashboard Service**:

| Aspect | Dashboard Service | PDF Service |
|--------|------------------|-------------|
| **Percentages** | Include all entries | Exclude topic entries (share of voice) |
| **Title Entries** | Pre-calculated hashes only | Full ActiveRecord relation for charts |
| **Temporal Intelligence** | ✅ Included | ❌ Not needed for PDF |
| **Caching** | Heavy caching | Lighter caching (one-time generation) |

### 2. Updated Controller

**File**: `app/controllers/topic_controller.rb`

**Changes**:

```ruby
# Before
def pdf
  dashboard_data = DigitalDashboardServices::AggregatorService.call(topic: @topic)
  assign_topic_data(dashboard_data[:topic_data])
  assign_chart_data(dashboard_data[:chart_data])
  assign_tags_and_words(dashboard_data[:tags_and_words])
  calculate_percentages_for_pdf  # Special PDF calculation
  render layout: false
end

# After
def pdf
  pdf_data = DigitalDashboardServices::PdfService.call(topic: @topic)
  assign_topic_data(pdf_data[:topic_data])
  assign_chart_data(pdf_data[:chart_data])
  assign_tags_and_words(pdf_data[:tags_and_words])
  assign_percentages(pdf_data[:percentages])  # Uses PDF service percentages
  render layout: false
end
```

**Removed**:
- `calculate_percentages_for_pdf` method (moved to PDF service)

**Updated**:
- `assign_chart_data` now conditionally assigns `@title_chart_entries` only when present

### 3. Cleaned Dashboard Service

**File**: `app/services/digital_dashboard_services/aggregator_service.rb`

**Removed**:
- PDF-specific `title_chart_entries` relation loading
- Simplified to only return data needed for dashboard view

---

## PDF Service Structure

```ruby
module DigitalDashboardServices
  class PdfService < ApplicationService
    def call
      {
        topic_data: load_topic_data,
        chart_data: load_chart_data,
        tags_and_words: load_tags_and_words,
        percentages: calculate_pdf_percentages
      }
    end
    
    private
    
    def load_topic_data
      # Same as dashboard service
    end
    
    def load_chart_data
      # Dashboard stats + title_chart_entries relation
      {
        # ... standard chart data ...
        title_chart_entries: Entry.enabled.normal_range
                                   .tagged_with(tag_names, any: true, on: :title_tags)
                                   .includes(:tags, :site)
      }
    end
    
    def calculate_pdf_percentages
      # Exclude topic entries for share of voice calculation
      all_entries = Entry.enabled.normal_range
      topic_entry_ids = topic_data[:entries].pluck(:id)
      all_entries_size = all_entries.where.not(id: topic_entry_ids).count
      all_entries_interactions = all_entries.where.not(id: topic_entry_ids).sum(:total_count)
      
      # Calculate share of voice percentages
      # ...
    end
  end
end
```

---

## Benefits

### 1. **Separation of Concerns** ✅
- Dashboard logic in `AggregatorService`
- PDF logic in `PdfService`
- No mixing of different requirements

### 2. **Easier Maintenance** 🔧
- PDF changes don't affect dashboard
- Dashboard changes don't affect PDF
- Clear responsibilities per service

### 3. **Better Testing** 🧪
- Can test PDF logic independently
- Can test dashboard logic independently
- No need to test irrelevant scenarios

### 4. **Performance** ⚡
- Dashboard doesn't load unnecessary PDF data
- PDF doesn't calculate unnecessary temporal intelligence
- Each optimized for its use case

### 5. **Clarity** 📖
- Clear what data is for PDF vs dashboard
- Easier to understand for new developers
- Self-documenting code structure

---

## Usage

### Regular Dashboard View

```ruby
# In TopicController#show
dashboard_data = DigitalDashboardServices::AggregatorService.call(topic: @topic)
```

**Returns**:
- topic_data
- chart_data (hashes only)
- percentages (all entries)
- tags_and_words
- temporal_intelligence

### PDF Generation

```ruby
# In TopicController#pdf
pdf_data = DigitalDashboardServices::PdfService.call(topic: @topic)
```

**Returns**:
- topic_data
- chart_data (includes `title_chart_entries` relation)
- percentages (share of voice calculation)
- tags_and_words

---

## Testing

Both services should be tested independently:

```ruby
# Test dashboard service
RSpec.describe DigitalDashboardServices::AggregatorService do
  it "loads temporal intelligence for dashboard"
  it "calculates percentages including all entries"
  it "returns chart data as hashes"
end

# Test PDF service
RSpec.describe DigitalDashboardServices::PdfService do
  it "calculates share of voice percentages"
  it "provides title_chart_entries relation"
  it "excludes topic entries from percentage calculation"
end
```

---

## Future Considerations

### Other PDF Services

Consider creating similar PDF services for:
- `FacebookDashboardServices::PdfService`
- `TwitterDashboardServices::PdfService`
- `GeneralDashboardServices::PdfService`

### Shared PDF Logic

If common PDF logic emerges, consider:
- `PdfServices::BaseService` with shared methods
- Helper modules for common calculations
- Shared formatters for PDF output

---

## Related Files

### Services
- `app/services/digital_dashboard_services/aggregator_service.rb`
- `app/services/digital_dashboard_services/pdf_service.rb`

### Controllers
- `app/controllers/topic_controller.rb`

### Views
- `app/views/topic/show.html.erb` (uses AggregatorService)
- `app/views/topic/pdf.html.erb` (uses PdfService)

---

## Rollback

If needed to rollback:

1. Remove `pdf_service.rb`
2. Restore `calculate_percentages_for_pdf` method in controller
3. Add `title_chart_entries` back to `AggregatorService`
4. Update PDF action to use `AggregatorService` + `calculate_percentages_for_pdf`

---

**Status**: ✅ Completed  
**Impact**: Low risk - Isolated change, doesn't affect dashboard view  
**Testing**: Manual test PDF generation for topic #1

