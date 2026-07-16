#!/usr/bin/env ruby
# Wires the iOS Tunnel spike into Runner.xcodeproj (idempotent). Assumes the
# Tunnel target already exists (created in Xcode: New Target → Packet Tunnel
# Provider). Adds our sources to the right targets and links the mihomo engine.
# Run via ./setup_tunnel.sh (sets the xcodeproj gem env). Close Xcode first.
require 'xcodeproj'

proj_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(proj_path)

runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'
tunnel = project.targets.find { |t| t.name == 'Tunnel' } or abort 'Tunnel target missing (create it in Xcode first)'

def target_has?(target, basename)
  target.source_build_phase.files.any? { |f| (f.file_ref&.path || '').end_with?(basename) }
end

# --- Runner: host-side VPN channel sources (ios/Runner/VPN/*) ---
runner_group = project['Runner'] || project.main_group
vpn_group = runner_group['VPN'] || runner_group.new_group('VPN', 'VPN')
%w[VPNManager.swift VpnChannel.swift].each do |name|
  if target_has?(runner, name)
    puts "skip (Runner already has): #{name}"
  else
    runner.add_file_references([vpn_group.new_reference(name)])
    puts "added to Runner: VPN/#{name}"
  end
end

# --- Tunnel: PacketTunnelProvider.swift ---
# Xcode 16 created the Tunnel target with a file-system SYNCHRONIZED group, so
# every .swift in ios/Tunnel/ (including our provider, which replaced Xcode's
# stub in place) is compiled into the target automatically — no file ref to add.
puts 'Tunnel sources: auto-synced from ios/Tunnel/ (PacketTunnelProvider.swift included)'

# --- Tunnel: link MihomoCore.xcframework (relative to ios/ = ../native/...) ---
rel = '../native/mihomocore/MihomoCore.xcframework'
ref = project.files.find { |f| f.path == rel }
unless ref
  fw_group = project['Frameworks'] || project.new_group('Frameworks')
  ref = fw_group.new_reference(rel)
  puts "added file reference: #{rel}"
end
phase = tunnel.frameworks_build_phase
if phase.files_references.include?(ref)
  puts 'skip (already linked to Tunnel)'
else
  phase.add_file_reference(ref, true)
  puts 'linked MihomoCore.xcframework to Tunnel'
end

search = '$(SRCROOT)/../native/mihomocore'
tunnel.build_configurations.each do |c|
  paths = c.build_settings['FRAMEWORK_SEARCH_PATHS'] || ['$(inherited)']
  paths = [paths] unless paths.is_a?(Array)
  next if paths.include?(search)
  paths << search
  c.build_settings['FRAMEWORK_SEARCH_PATHS'] = paths
  puts "search path += #{search} (#{c.name})"
end

# mihomo's static archive needs system libs it doesn't carry: libresolv
# (res_9_* DNS symbols), Security + CoreFoundation (cgo crypto/net). Same as
# macOS; all exist on iOS too.
tunnel.build_configurations.each do |c|
  ld = c.build_settings['OTHER_LDFLAGS'] || []
  ld = [ld] unless ld.is_a?(Array)
  next if ld.include?('-lresolv')
  ld = ['$(inherited)'] if ld.empty?
  ld += ['-lresolv', '-framework', 'Security', '-framework', 'CoreFoundation']
  c.build_settings['OTHER_LDFLAGS'] = ld
  puts "OTHER_LDFLAGS += -lresolv +Security +CoreFoundation (#{c.name})"
end

project.save
puts 'saved Runner.xcodeproj'
