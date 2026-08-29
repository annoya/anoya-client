#!/usr/bin/env ruby
# Appends the "Fix native-asset framework layout" build phase to the Runner
# target (idempotent): repoints the root Resources symlink of every embedded
# framework that Flutter's native-assets builder laid out wrong. See the script
# body below for why. Must stay the last phase — it has to run after the
# frameworks are embedded and before Xcode signs the app.
require 'xcodeproj'

PHASE_NAME = 'Fix native-asset framework layout'

SCRIPT = <<~SH
  # Flutter's native-assets builder points a framework's root Resources link
  # straight at Versions/A instead of Versions/Current (flutter_tools
  # src/isolated/native_assets/macos/native_assets.dart). The layout comment
  # right above that code says Current, the code says A; the sibling dylib link
  # goes through Current correctly. Apple rejects the archive over it:
  # ITMS-90291 "must contain a symbolic link 'Resources' ->
  # 'Versions/Current/Resources'". Today only objective_c arrives this way;
  # every CocoaPods framework is already correct, so this is a no-op for them.
  #
  # Repointing after the fact is safe: a framework's signature does not seal
  # the symlinks at its root, so the framework stays valid without re-signing.
  set -euo pipefail
  frameworks="$CODESIGNING_FOLDER_PATH/Contents/Frameworks"
  [ -d "$frameworks" ] || exit 0
  for fw in "$frameworks"/*.framework; do
    link="$fw/Resources"
    [ -L "$link" ] || continue
    [ "$(readlink "$link")" = "Versions/A/Resources" ] || continue
    ln -sfn Versions/Current/Resources "$link"
    echo "note: repointed Resources symlink in $(basename "$fw")"
  done
SH

proj_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(proj_path)

target = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless target

phase = target.build_phases.find do |ph|
  ph.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && ph.name == PHASE_NAME
end

if phase
  puts 'skip (phase already present)'
else
  phase = target.new_shell_script_build_phase(PHASE_NAME)
  puts 'added build phase'
end

phase.shell_path = '/bin/sh'
phase.shell_script = SCRIPT
# No declared inputs/outputs, so let it run every build rather than be skipped
# by dependency analysis.
phase.always_out_of_date = '1'

# Keep it last: the frameworks are not in place until "Embed Pods Frameworks"
# and Flutter's assemble phase have run.
target.build_phases.delete(phase)
target.build_phases << phase

project.save
puts "Runner phases: #{target.build_phases.map { |ph| ph.respond_to?(:name) && ph.name ? ph.name : ph.class.name.split('::').last }.join(' | ')}"
