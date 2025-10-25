# frozen_string_literal: true

namespace :twitter do
  desc 'Update Twitter Profile Stats'
  task update_profiles: :environment do
    profiles = TwitterProfile.where.not(uid: nil)
    profiles.each do |profile|
      puts "Processing Twitter Profile: #{profile.name || profile.username}"
      response = TwitterServices::UpdateProfile.call(profile.uid)
      if response.success?
        profile.update!(response.data)
        puts "  -> Updated: #{profile.name} (@#{profile.username}) - #{profile.followers} followers"
      else
        puts "  -> Error: #{response.error}"
      end
    end
  end
end
