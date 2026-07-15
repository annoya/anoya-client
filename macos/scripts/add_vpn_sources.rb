#!/usr/bin/env ruby
# Adds the host-app VPN sources to the Runner target (idempotent).
# Run via: ./macos/scripts/add_vpn_sources.sh   (sets the xcodeproj gem env)
require 'xcodeproj'

proj_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(proj_path)

target = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless target

runner_group = project.main_group['Runner'] || project.main_group
vpn_group = runner_group['VPN'] || runner_group.new_group('VPN', 'VPN')

existing = target.source_build_phase.files.map { |f| f.file_ref&.path }.compact
%w[VPNManager.swift VpnChannel.swift].each do |name|
  rel = "VPN/#{name}"
  if existing.include?(name) || existing.include?(rel)
    puts "skip (already added): #{name}"
    next
  end
  ref = vpn_group.new_reference(name)
  target.add_file_references([ref])
  puts "added to Runner: #{rel}"
end

# SSO: the web-auth bridge lives directly under Runner/.
%w[WebAuthChannel.swift].each do |name|
  if existing.include?(name)
    puts "skip (already added): #{name}"
    next
  end
  ref = runner_group.new_reference(name)
  target.add_file_references([ref])
  puts "added to Runner: #{name}"
end

project.save
puts 'saved Runner.xcodeproj'
