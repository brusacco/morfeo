# frozen_string_literal: true

# Feature flags for gradual rollout
FEATURE_FLAGS = {
  # Use direct Entry-Topic associations instead of acts_as_taggable_on
  # Set via ENV: USE_DIRECT_ENTRY_TOPICS=true
  use_direct_entry_topics: ENV.fetch('USE_DIRECT_ENTRY_TOPICS', 'false') == 'true'
}.freeze

# Log feature flags on startup
Rails.logger.info "Feature Flags: #{FEATURE_FLAGS.inspect}"

