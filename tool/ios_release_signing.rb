#!/usr/bin/env ruby
# Apply signing only in the disposable release checkout; never commit identities.
require 'json'
require 'xcodeproj'

abort 'Usage: ios_release_signing.rb STATE_JSON [PROJECT_PATH]' unless (1..2).cover?(ARGV.length)
state = JSON.parse(File.read(ARGV[0]))
project = Xcodeproj::Project.open(ARGV[1] || 'ios/Runner.xcodeproj')
expected = { 'Runner' => 'net.salatime.app', 'SalaTimeWidget' => 'net.salatime.app.SalaTimeWidget' }
expected.each do |name, bundle_id|
  target = project.targets.find { |candidate| candidate.name == name }
  abort "Missing target: #{name}" unless target
  profile = state.fetch('profiles').fetch(name)
  abort "Unexpected profile bundle for #{name}" unless profile.fetch('bundle_id') == bundle_id
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    settings['DEVELOPMENT_TEAM'] = state.fetch('team_id')
    settings['CODE_SIGN_STYLE'] = 'Manual'
    settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
    settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Distribution'
    settings['PROVISIONING_PROFILE_SPECIFIER'] = profile.fetch('uuid')
    settings['PROVISIONING_PROFILE'] = profile.fetch('uuid')
    settings['SALATIME_APP_GROUP'] = 'group.net.salatime.app'
    if name == 'Runner' && !state.fetch('google_reversed_client_id', '').empty?
      settings['SALATIME_GOOGLE_REVERSED_CLIENT_ID'] = state.fetch('google_reversed_client_id')
    end
  end
end
project.save
# Reopen to catch accidental target/configuration omissions before compilation.
verified = Xcodeproj::Project.open(project.path)
expected.each do |name, bundle_id|
  target = verified.targets.find { |candidate| candidate.name == name }
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    abort "Signing verification failed: #{name}/#{configuration.name}" unless
      settings['PRODUCT_BUNDLE_IDENTIFIER'] == bundle_id &&
      settings['CODE_SIGN_STYLE'] == 'Manual' &&
      settings['DEVELOPMENT_TEAM'] == state.fetch('team_id') &&
      settings['PROVISIONING_PROFILE_SPECIFIER'] == state.fetch('profiles').fetch(name).fetch('uuid') &&
      settings['SALATIME_APP_GROUP'] == 'group.net.salatime.app'
  end
end
puts 'Manual signing verified for Runner and SalaTimeWidget.'
