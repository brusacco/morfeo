# frozen_string_literal: true

namespace :twitter do
  namespace :accounts do
    desc 'Check status of all Twitter accounts (rate limits, cooldowns)'
    task status: :environment do
      puts "\n" + "=" * 80
      puts "TWITTER ACCOUNTS STATUS"
      puts "=" * 80

      begin
        manager = TwitterServices::AccountManager.new
        status = manager.accounts_status

        status.each do |account|
          puts "\n#{account[:name]} (Index: #{account[:index]})"
          puts "  Status: #{account[:available] ? '✅ AVAILABLE' : '❌ RATE LIMITED'}"
          
          if account[:rate_limited]
            minutes = (account[:cooldown_remaining_seconds] / 60.0).ceil
            puts "  Cooldown: #{minutes} minutes remaining (#{account[:cooldown_remaining_seconds]}s)"
          else
            puts "  Ready to use"
          end
        end

        # Summary
        available_count = status.count { |a| a[:available] }
        puts "\n" + "-" * 80
        puts "Summary: #{available_count}/#{status.count} accounts available"
        puts "=" * 80 + "\n"

      rescue StandardError => e
        puts "\n❌ Error checking account status: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
      end
    end

    desc 'Clear all rate limit cooldowns (use if tokens were refreshed)'
    task clear_cooldowns: :environment do
      puts "\n⚠️  Clearing all Twitter account rate limit cooldowns..."
      
      # Clear all rate limit cache keys (supports up to 3 accounts)
      [0, 1, 2].each do |index|
        cache_key = "twitter_account_manager:rate_limited:account_#{index}"
        Rails.cache.delete(cache_key)
      end
      
      puts "✅ All cooldowns cleared. Run 'rake twitter:accounts:status' to verify.\n"
    end

    desc 'Test account rotation by simulating rate limit'
    task test_rotation: :environment do
      puts "\n" + "=" * 80
      puts "TESTING TWITTER ACCOUNT ROTATION"
      puts "=" * 80 + "\n"

      begin
        manager = TwitterServices::AccountManager.new
        
        puts "Initial status:"
        manager.accounts_status.each do |account|
          status = account[:available] ? '✅ Available' : '❌ Rate Limited'
          puts "  #{account[:name]}: #{status}"
        end

        # Get first account
        creds1 = manager.get_active_credentials
        puts "\n1️⃣  Active account: #{creds1[:name]}"
        
        # Simulate rate limit on first account
        puts "\n🔄 Simulating rate limit on #{creds1[:name]}..."
        manager.mark_rate_limited(creds1[:account_index], "Test rate limit")
        
        # Should rotate to second account
        creds2 = manager.get_active_credentials
        puts "2️⃣  Active account after rotation: #{creds2[:name]}"
        
        if creds1[:account_index] != creds2[:account_index]
          puts "\n✅ SUCCESS: Account rotation working correctly!"
        else
          puts "\n⚠️  WARNING: Still using same account (may be no other accounts available)"
        end

        puts "\nFinal status:"
        manager.accounts_status.each do |account|
          status = account[:available] ? '✅ Available' : '❌ Rate Limited'
          cooldown = account[:rate_limited] ? " (#{(account[:cooldown_remaining_seconds] / 60.0).ceil}m cooldown)" : ''
          puts "  #{account[:name]}: #{status}#{cooldown}"
        end

        puts "\n💡 Run 'rake twitter:accounts:clear_cooldowns' to reset for production use."
        puts "=" * 80 + "\n"

      rescue StandardError => e
        puts "\n❌ Error testing rotation: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
      end
    end

    desc 'Verify ENV variables are set correctly'
    task verify_env: :environment do
      puts "\n" + "=" * 80
      puts "TWITTER ENVIRONMENT VARIABLES"
      puts "=" * 80 + "\n"

      vars = [
        { name: 'TWITTER_AUTH_TOKEN', required: true },
        { name: 'TWITTER_CT0_TOKEN', required: true },
        { name: 'TWITTER_AUTH_TOKEN2', required: false },
        { name: 'TWITTER_CT0_TOKEN2', required: false },
        { name: 'TWITTER_AUTH_TOKEN3', required: false },
        { name: 'TWITTER_CT0_TOKEN3', required: false },
        { name: 'TWITTER_BEARER_TOKEN', required: false },
        { name: 'SCRAPE_DO_TOKEN', required: false }
      ]

      missing_required = []

      vars.each do |var|
        value = ENV[var[:name]]
        
        if value.present?
          # Show first 10 and last 5 characters for security
          masked = if value.length > 20
                     "#{value[0..9]}...#{value[-5..]}"
                   else
                     "#{value[0..5]}..."
                   end
          
          status = '✅'
          status_text = masked
        else
          status = var[:required] ? '❌ MISSING' : '⚪ Not set'
          status_text = ''
          missing_required << var[:name] if var[:required]
        end

        required_text = var[:required] ? '[REQUIRED]' : '[OPTIONAL]'
        puts "#{status} #{var[:name].ljust(25)} #{required_text.ljust(12)} #{status_text}"
      end

      puts "\n" + "-" * 80
      
      if missing_required.any?
        puts "❌ Missing required variables: #{missing_required.join(', ')}"
        puts "   Set these in your .env file or environment"
      else
        puts "✅ All required variables are set"
        
        # Check if we have backup accounts
        account2 = ENV['TWITTER_AUTH_TOKEN2'].present? && ENV['TWITTER_CT0_TOKEN2'].present?
        account3 = ENV['TWITTER_AUTH_TOKEN3'].present? && ENV['TWITTER_CT0_TOKEN3'].present?
        
        if account2 && account3
          puts "✅ Backup accounts configured (Account 2 & Account 3)"
        elsif account2
          puts "✅ Backup account configured (Account 2)"
          puts "💡 Consider adding Account 3 for extra capacity"
        elsif account3
          puts "⚠️  Account 3 configured but Account 2 missing (configure Account 2 first)"
        else
          puts "⚠️  No backup account configured (rate limiting may cause failures)"
          puts "   Consider setting TWITTER_AUTH_TOKEN2 and TWITTER_CT0_TOKEN2"
        end
      end
      
      puts "=" * 80 + "\n"
    end
  end
end

