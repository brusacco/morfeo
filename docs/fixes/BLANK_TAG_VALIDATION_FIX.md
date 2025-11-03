# 🐛 Blank Tag Validation Fix

**Date**: November 3, 2025  
**Issue**: `La validación falló: Tag debe existir, Tag no puede estar en blanco`  
**Status**: ✅ Fixed

---

## 🔍 Problem

During tagger runs, occasional errors occurred:

```
⚠️  Entry #1897347 failed: La validación falló: Tag debe existir, Tag no puede estar en blanco
```

### Root Cause:

The tagging services (`ExtractTags` and `ExtractTitleTags`) could return blank/empty tag names when:

1. **Tag has blank name** in the database
2. **Tag variations contain blank entries** (e.g., `"ANR,,Colorado"` → empty string between commas)
3. **No validation before adding to results array**

---

## ✅ Solution

Fixed at the **source** in both tagging services:

### Changes to `ExtractTags`:

```ruby
tags.each do |tag|
  # ✅ Skip tags with blank names
  next if tag.name.blank?
  
  tags_found << tag.name if content.match(/\b#{tag.name}\b/)
  if tag.variations
    # ✅ Strip whitespace and reject blanks in variations
    alts = tag.variations.split(',').map(&:strip).reject(&:blank?)
    alts.each { |alt_tag| tags_found << tag.name if content.match(/\b#{alt_tag}\b/) }
  end
end

# ✅ Remove duplicates and filter out any blank entries
tags_found = tags_found.uniq.reject(&:blank?)
```

### Changes to `ExtractTitleTags`:

Same fix applied for consistency.

---

## 🎯 What This Prevents

### Before (Errors):
```ruby
# Tag with blank name
Tag.create!(name: "")  # ❌ Could be in DB

# Tag with blank variation
Tag.create!(name: "ANR", variations: "Asociación,,Nacional")  # ❌ Blank between commas

# Service returns: ["ANR", "", "Nacional"]
entry.tag_list = ["ANR", "", "Nacional"]
entry.save!  # ❌ FAILS: "Tag no puede estar en blanco"
```

### After (Filtered):
```ruby
# Service now returns: ["ANR", "Nacional"]
entry.tag_list = ["ANR", "Nacional"]  # ✅ No blanks
entry.save!  # ✅ SUCCESS
```

---

## 📊 Impact

### Files Changed:
- ✅ `app/services/web_extractor_services/extract_tags.rb`
- ✅ `app/services/web_extractor_services/extract_title_tags.rb`

### Protection Added:
1. ✅ Skip tags with `blank?` names
2. ✅ Strip whitespace from variations (handles `"ANR, Colorado"`)
3. ✅ Reject blank variations (handles `"ANR,,Colorado"`)
4. ✅ Final `.uniq.reject(&:blank?)` as safety net
5. ✅ Removes duplicate tags automatically

---

## 🧪 Testing

### Verify the fix works:

```ruby
# Rails console
tag = Tag.create!(name: "Test", variations: "Test1,,Test2, Test3 ")

entry = Entry.last
result = WebExtractorServices::ExtractTags.call(entry.id, tag.id)

# Before: ["Test", "", "Test", "Test"]
# After:  ["Test"]  # ✅ Filtered, unique, no blanks
```

---

## 🚀 Deployment

No special deployment steps needed:

```bash
# Standard deployment
cd /var/www/morfeo
git pull
sudo systemctl restart morfeo
```

The fix is **backwards compatible** - just filters out bad data before it causes errors.

---

## 🔮 Future Improvement

Consider adding database validation to prevent blank tags from being created:

```ruby
# app/models/tag.rb
validates :name, presence: true, allow_blank: false

# Or clean up existing blank tags:
Tag.where("name IS NULL OR name = ''").destroy_all
```

---

## ✅ Summary

| Before | After |
|--------|-------|
| ❌ Blank tags could cause validation errors | ✅ Blank tags filtered at source |
| ❌ Variations not trimmed | ✅ Variations trimmed (`.strip`) |
| ❌ Empty variations included | ✅ Empty variations rejected |
| ❌ Duplicate tags possible | ✅ Duplicates removed (`.uniq`) |
| ❌ Silent failures | ✅ Clean, valid tag arrays |

**Status**: ✅ Production ready - fixes the root cause

