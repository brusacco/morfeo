#!/usr/bin/env ruby
# frozen_string_literal: true

# Script para verificar configuración de cuentas de Twitter
# Uso: ruby scripts/verify_twitter_accounts.rb

require_relative '../config/environment'

puts "\n" + "=" * 80
puts "TWITTER ACCOUNT ROTATION - VERIFICATION SCRIPT"
puts "=" * 80 + "\n"

# 1. Verificar ENV variables
puts "📋 Step 1: Checking Environment Variables"
puts "-" * 80

required_vars = ['TWITTER_AUTH_TOKEN', 'TWITTER_CT0_TOKEN']
optional_vars = ['TWITTER_AUTH_TOKEN2', 'TWITTER_CT0_TOKEN2', 'TWITTER_AUTH_TOKEN3', 'TWITTER_CT0_TOKEN3']

missing = required_vars.select { |var| ENV[var].blank? }

if missing.any?
  puts "❌ ERROR: Missing required variables: #{missing.join(', ')}"
  puts "\nSet these in your .env file:"
  missing.each do |var|
    puts "  #{var}=your_value_here"
  end
  exit 1
else
  puts "✅ Required variables are set (TWITTER_AUTH_TOKEN, TWITTER_CT0_TOKEN)"
end

backup2_configured = ENV['TWITTER_AUTH_TOKEN2'].present? && ENV['TWITTER_CT0_TOKEN2'].present?
backup3_configured = ENV['TWITTER_AUTH_TOKEN3'].present? && ENV['TWITTER_CT0_TOKEN3'].present?

if backup2_configured && backup3_configured
  puts "✅ Backup accounts configured (Account 2 & Account 3)"
elsif backup2_configured
  puts "✅ Backup account configured (Account 2)"
  puts "💡 Consider adding Account 3 for extra capacity (TWITTER_AUTH_TOKEN3, TWITTER_CT0_TOKEN3)"
elsif backup3_configured
  puts "⚠️  Account 3 configured but Account 2 missing (Account 2 should be configured first)"
else
  puts "⚠️  No backup accounts configured (recommended for production)"
  puts "   Add TWITTER_AUTH_TOKEN2 and TWITTER_CT0_TOKEN2 for rotation"
end

# 2. Inicializar AccountManager
puts "\n📋 Step 2: Initializing Account Manager"
puts "-" * 80

begin
  manager = TwitterServices::AccountManager.new
  puts "✅ Account Manager initialized successfully"
rescue StandardError => e
  puts "❌ ERROR: Failed to initialize Account Manager: #{e.message}"
  exit 1
end

# 3. Ver estado de cuentas
puts "\n📋 Step 3: Checking Account Status"
puts "-" * 80

status = manager.accounts_status
status.each do |account|
  status_icon = account[:available] ? '✅' : '❌'
  status_text = account[:available] ? 'AVAILABLE' : 'RATE LIMITED'
  
  puts "#{status_icon} #{account[:name]}: #{status_text}"
  
  if account[:rate_limited]
    minutes = (account[:cooldown_remaining_seconds] / 60.0).ceil
    puts "   └─ Cooldown: #{minutes} minutes remaining"
  end
end

available_count = status.count { |a| a[:available] }
puts "\n   Summary: #{available_count}/#{status.count} accounts available"

# 4. Test de selección de cuenta
puts "\n📋 Step 4: Testing Account Selection"
puts "-" * 80

begin
  credentials = manager.get_active_credentials
  puts "✅ Active account selected: #{credentials[:name]}"
  puts "   └─ Index: #{credentials[:account_index]}"
  puts "   └─ Has auth_token: #{credentials[:auth_token].present?}"
  puts "   └─ Has ct0_token: #{credentials[:ct0_token].present?}"
rescue StandardError => e
  puts "❌ ERROR: Failed to get credentials: #{e.message}"
  exit 1
end

# 5. Test de detección de rate limit
puts "\n📋 Step 5: Testing Rate Limit Detection"
puts "-" * 80

test_errors = [
  'Rate limit exceeded',
  'Too Many Requests',
  'code: 88',
  'code: 429',
  'Normal error message'
]

test_errors.each do |error|
  is_rate_limit = TwitterServices::AccountManager.rate_limit_error?(error)
  icon = is_rate_limit ? '✅' : '⚪'
  puts "#{icon} '#{error}' → #{is_rate_limit ? 'DETECTED' : 'Not rate limit'}"
end

# 6. Test de rotación (simulado)
puts "\n📋 Step 6: Testing Account Rotation (Simulated)"
puts "-" * 80

if status.count > 1
  puts "Simulating rate limit on current account..."
  
  initial_creds = manager.get_active_credentials
  puts "   Before: #{initial_creds[:name]} (Index: #{initial_creds[:account_index]})"
  
  # Marcar como rate limited
  manager.mark_rate_limited(initial_creds[:account_index], "Simulated rate limit for testing")
  
  # Obtener nueva cuenta
  new_creds = manager.get_active_credentials
  puts "   After:  #{new_creds[:name]} (Index: #{new_creds[:account_index]})"
  
  if initial_creds[:account_index] != new_creds[:account_index]
    puts "✅ Rotation working: Successfully switched accounts"
    
    # Limpiar el test
    puts "\n   Cleaning up test state..."
    Rails.cache.delete("twitter_account_manager:rate_limited:account_#{initial_creds[:account_index]}")
    puts "   ✅ Test state cleaned"
  else
    puts "⚠️  Still using same account (no other accounts available)"
  end
else
  puts "⚠️  Only one account configured, cannot test rotation"
  puts "   Add TWITTER_AUTH_TOKEN2/TWITTER_CT0_TOKEN2 (and optionally TOKEN3) for rotation testing"
end

# 7. Resumen Final
puts "\n" + "=" * 80
puts "VERIFICATION COMPLETE"
puts "=" * 80

all_checks_passed = missing.empty? && manager && available_count > 0

if all_checks_passed
  puts "\n✅ All checks passed! The system is ready to use."
  puts "\n💡 Next steps:"
  puts "   1. Test with actual Twitter API call:"
  puts "      rails c"
  puts "      > TwitterServices::GetPostsDataAuth.call('123456789')"
  puts "\n   2. Monitor account status:"
  puts "      rake twitter:accounts:status"
  puts "\n   3. View detailed documentation:"
  puts "      docs/implementation/TWITTER_ACCOUNT_ROTATION_SYSTEM.md"
else
  puts "\n⚠️  Some checks failed. Please review the errors above."
  puts "\n💡 Common solutions:"
  puts "   - Ensure all required ENV variables are set in .env"
  puts "   - Verify tokens are valid (not expired)"
  puts "   - Check that Rails.cache is working (Redis/memory store)"
end

puts "\n" + "=" * 80 + "\n"

