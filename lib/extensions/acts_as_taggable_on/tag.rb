# frozen_string_literal: true

# lib/extensions/acts_as_taggable_on/tag.rb
module ActsAsTaggableOn
  class Tag
    attr_accessor :interactions

    def self.interactions(_entries)
      0
    end
  end
end
