# Tag Controller Security Fix

**Date**: November 2, 2025  
**Issue**: Unauthorized Tag Access  
**Severity**: 🔴 **HIGH** (Authorization Bypass)  
**Status**: ✅ **FIXED**

---

## 🔴 Problem Discovered

The `TagController` was **not checking if users had access to the topics that use a tag**, allowing users to bypass topic-based access control.

### Security Flaw

**Before:**
```ruby
class TagController < ApplicationController
  before_action :authenticate_user!  # ✅ User is authenticated
  
  def show
    @tag = Tag.find(params[:id])  # ❌ Gets ANY tag
    @entries = @tag.list_entries  # ❌ Shows ALL entries for that tag
  end
end
```

**Problem:**
- User authenticates ✅
- But no check if user has access to topics using that tag ❌
- User can access `/tag/{any_tag_id}/show` and see confidential data

### Attack Scenario

1. User A has access to Topic "Elections" (uses Tag "Santiago Peña")
2. User B has access to Topic "Corruption" (uses Tag "Horacio Cartes")  
3. But there's also Tag "Executive Project" used by Topic "CEO Only"
4. **User A/B can visit `/tag/{executive_tag_id}/show` and bypass topic restrictions!**

---

## ✅ Solution Implemented

### 1. Created `TagAuthorizable` Concern

**File**: `app/controllers/concerns/tag_authorizable.rb`

```ruby
module TagAuthorizable
  extend ActiveSupport::Concern

  private

  def authorize_tag_access!
    unless can_access_tag?
      handle_unauthorized_tag_access
    end
  end

  def can_access_tag?
    tag_exists? && user_has_tag_access?
  end

  def user_has_tag_access?
    return false unless @tag.present?
    
    # Get user's topic IDs
    user_topic_ids = @topicos.pluck(:id)
    
    # Check if tag is used by any of user's topics
    @tag.topics.where(id: user_topic_ids, status: true).exists?
  end
end
```

**Logic:**
- User can only access tag if **at least one of their topics uses it**
- Uses `@topicos` (set in ApplicationController) which contains user's authorized topics
- Blocks access if tag is not used by any of user's topics

### 2. Updated `TagController`

**File**: `app/controllers/tag_controller.rb`

**Changes:**
```ruby
class TagController < ApplicationController
  include TagAuthorizable  # ✅ Added concern
  
  before_action :authenticate_user!
  before_action :set_tag, only: [:show, :comments, :report]  # ✅ Set tag first
  before_action :authorize_tag_access!, only: [:show, :comments, :report]  # ✅ Then authorize
  
  def show
    # @tag already set and authorized
    @entries = @tag.list_entries.includes(:site, :tags)
    # ... rest of method
  end
  
  private
  
  def set_tag
    @tag = Tag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Tag no encontrado.'
  end
end
```

---

## 🔒 Security Flow (Now)

```
User Request: /tag/123/show
  ↓
1. authenticate_user! → ✅ User must be logged in
  ↓
2. set_tag → ✅ Load @tag (Tag ID: 123)
  ↓
3. authorize_tag_access! → 🔍 Check authorization
  ↓
  → Get user's topics: @topicos (set by ApplicationController)
  → Check if tag belongs to any of user's topics
  → Tag.topics.where(id: user_topic_ids).exists?
  ↓
  ✅ YES → Allow access, show entries
  ❌ NO → Redirect to root with "No tienes acceso a este tag"
```

---

## 📝 Actions Protected

### Before Fix (Vulnerable):
- ❌ `show` - Anyone could view any tag
- ❌ `comments` - Anyone could view tag comments  
- ❌ `report` - Anyone could generate tag reports
- ✅ `entries_data` - No authorization (AJAX endpoint, separate issue)
- ✅ `search` - No authorization (search autocomplete, low risk)

### After Fix (Secure):
- ✅ `show` - Only if user has access to topics using tag
- ✅ `comments` - Only if user has access to topics using tag
- ✅ `report` - Only if user has access to topics using tag
- ⚠️ `entries_data` - Needs separate fix (see below)
- ⚠️ `search` - Consider adding rate limiting

---

## ⚠️ Remaining Issues

### 1. `entries_data` Method (AJAX endpoint)

**Current Code:**
```ruby
def entries_data
  tag_id = params[:tag_id]
  tag = Tag.find_by(id: tag_id)
  # No authorization check!
  entries = tag.list_entries
  # ...
end
```

**Recommendation:** Add authorization check here too, or only allow this to be called from authorized pages.

### 2. API Endpoints Not Secured

**File**: `app/controllers/api/v1/tags_controller.rb`

```ruby
class Api::V1::TagsController < ApplicationController
  # NO authentication!
  
  def popular
    entries = Entry.where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(50)
    @tags = entries.tag_counts_on(:tags).order('count desc')
  end
end
```

**Issue:** Public API exposes tag data  
**Recommendation:** 
- Add authentication if this is internal API
- OR document as intentionally public
- OR rate limit to prevent abuse

---

## 🧪 Testing

### Manual Testing

1. **Test as User A** (has access to Topic 1):
   ```
   Visit /tag/{topic1_tag_id}/show → ✅ Should work
   Visit /tag/{topic2_tag_id}/show → ❌ Should get "No tienes acceso"
   ```

2. **Test as User B** (has access to Topic 2):
   ```
   Visit /tag/{topic1_tag_id}/show → ❌ Should get "No tienes acceso"
   Visit /tag/{topic2_tag_id}/show → ✅ Should work
   ```

3. **Test shared tags** (Tag used by both Topic 1 and Topic 2):
   ```
   Visit /tag/{shared_tag_id}/show → ✅ Both users should see it
   ```

### Automated Testing (Recommended)

```ruby
# spec/controllers/tag_controller_spec.rb
RSpec.describe TagController, type: :controller do
  let(:user) { create(:user) }
  let(:topic1) { create(:topic) }
  let(:topic2) { create(:topic) }
  let(:tag1) { create(:tag, topics: [topic1]) }
  let(:tag2) { create(:tag, topics: [topic2]) }
  
  before { sign_in user }
  
  context 'when user has access to topic' do
    before { user.topics << topic1 }
    
    it 'allows access to tag' do
      get :show, params: { id: tag1.id }
      expect(response).to be_successful
    end
  end
  
  context 'when user does not have access to topic' do
    before { user.topics << topic1 }
    
    it 'denies access to tag' do
      get :show, params: { id: tag2.id }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('No tienes acceso a este tag.')
    end
  end
end
```

---

## 📊 Impact Assessment

### Before Fix:
- ❌ **Authorization Bypass**: Users could access any tag
- ❌ **Data Leakage**: Users could see entries from restricted topics
- ❌ **Compliance Risk**: Violates access control requirements

### After Fix:
- ✅ **Proper Authorization**: Users can only access tags from their topics
- ✅ **Data Isolation**: Users only see data from authorized topics
- ✅ **Consistent with Topic Security**: Matches TopicController authorization pattern

---

## 🎯 Consistency Check

All controllers now follow consistent authorization patterns:

| Controller | Authorization | Pattern |
|------------|--------------|---------|
| ✅ TopicController | `TopicAuthorizable` | Topic-based |
| ✅ FacebookTopicController | `TopicAuthorizable` | Topic-based |
| ✅ TwitterTopicController | `TopicAuthorizable` | Topic-based |
| ✅ GeneralDashboardController | `TopicAuthorizable` | Topic-based |
| ✅ TagController | `TagAuthorizable` | Tag→Topic-based |
| ✅ EntryController | `authenticate_user!` | User-scoped cache |
| ✅ HomeController | `authenticate_user!` | User-scoped cache |
| ❌ Api::V1::* | None | **PUBLIC** ⚠️ |

---

## 📚 Related Fixes

This fix is part of a larger security audit:

1. ✅ **Cache Security** - User-scoped action caching (done today)
2. ✅ **Tag Authorization** - Tag→Topic access control (done now)
3. ⚠️ **API Security** - API endpoints need review
4. ⚠️ **AJAX Endpoints** - `entries_data` methods need authorization

---

## 📞 Recommendations

### Immediate:
- [x] Implement `TagAuthorizable` concern
- [x] Update `TagController` to use authorization
- [x] Test with multiple users
- [ ] Fix `entries_data` authorization

### Short-term:
- [ ] Audit all API endpoints (`api/v1/*_controller.rb`)
- [ ] Add authorization to AJAX endpoints
- [ ] Add rate limiting to public APIs

### Long-term:
- [ ] Add automated tests for authorization
- [ ] Document authorization patterns
- [ ] Security audit of all controllers

---

**Prepared by**: Cursor AI Assistant  
**Reviewed by**: [Pending]  
**Approved by**: [Pending]

