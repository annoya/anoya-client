#!/usr/bin/env ruby
# Fixes the Flutter+app-extension "Cycle inside Runner" build error by moving
# Flutter's "Thin Binary" script phase to be the LAST Runner build phase (after
# the appex + pods embed phases). Idempotent. Re-run after `flutter build`
# regenerates the project. Close Xcode first.
require 'xcodeproj'
p = Xcodeproj::Project.open(File.expand_path('../../Runner.xcodeproj', __FILE__))
t = p.targets.find { |x| x.name == 'Runner' } or abort 'Runner target missing'
thin = t.build_phases.find { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' }
abort 'Thin Binary phase not found' unless thin
if t.build_phases.last == thin
  puts 'skip (Thin Binary already last)'
else
  t.build_phases.delete(thin)
  t.build_phases << thin
  p.save
  puts 'moved Thin Binary to last; saved'
end
