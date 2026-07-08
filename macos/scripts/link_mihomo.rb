#!/usr/bin/env ruby
# Links MihomoCore.xcframework into the Tunnel target (idempotent):
#  - adds a file reference (relative to ../native/mihomocore),
#  - adds it to the Tunnel "Link Binary With Libraries" phase (link, not embed),
#  - adds its directory to FRAMEWORK_SEARCH_PATHS so `import MihomoCore` resolves.
require 'xcodeproj'

proj_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(proj_path)

target = project.targets.find { |t| t.name == 'Tunnel' }
abort 'Tunnel target not found' unless target

rel = '../native/mihomocore/MihomoCore.xcframework'

ref = project.files.find { |f| f.path == rel }
unless ref
  group = project['Frameworks'] || project.new_group('Frameworks')
  ref = group.new_reference(rel)
  puts "added file reference: #{rel}"
end

phase = target.frameworks_build_phase
if phase.files_references.include?(ref)
  puts 'skip (already linked to Tunnel)'
else
  phase.add_file_reference(ref, true)
  puts 'linked MihomoCore.xcframework to Tunnel'
end

search = '$(SRCROOT)/../native/mihomocore'
target.build_configurations.each do |c|
  paths = c.build_settings['FRAMEWORK_SEARCH_PATHS'] || ['$(inherited)']
  paths = [paths] unless paths.is_a?(Array)
  unless paths.include?(search)
    paths << search
    c.build_settings['FRAMEWORK_SEARCH_PATHS'] = paths
    puts "search path += #{search} (#{c.name})"
  end
end

# The mihomo Go runtime needs system libs the static archive doesn't carry:
# libresolv (DNS res_9_* symbols), Security + CoreFoundation (crypto/net cgo).
target.build_configurations.each do |c|
  ld = c.build_settings['OTHER_LDFLAGS'] || []
  ld = [ld] unless ld.is_a?(Array)
  next if ld.include?('-lresolv')
  ld = ['$(inherited)'] if ld.empty?
  ld += ['-lresolv', '-framework', 'Security', '-framework', 'CoreFoundation']
  c.build_settings['OTHER_LDFLAGS'] = ld
  puts "OTHER_LDFLAGS += -lresolv -framework Security -framework CoreFoundation (#{c.name})"
end

project.save
puts 'saved Runner.xcodeproj'
