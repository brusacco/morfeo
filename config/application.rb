# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# require_relative '../lib/extensions/acts_as_taggable_on/tag'
require_relative '../lib/extensions/anemone/encoding'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Morfeo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(7.0)
    config.i18n.default_locale = :es
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    config.time_zone = 'America/Asuncion'
    # config.eager_load_paths << Rails.root.join("extras")
    config.active_record.yaml_column_permitted_classes = [Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  end
end
