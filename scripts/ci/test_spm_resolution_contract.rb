# frozen_string_literal: true

require "yaml"

project_root = File.expand_path("../..", __dir__)
action_path = File.join(project_root, ".github/actions/deliver-app/action.yml")
fastfile_path = File.join(project_root, "fastlane/Fastfile")

action = YAML.load_file(action_path)
steps = action.fetch("runs").fetch("steps")
uses = steps.filter_map { |step| step["uses"] }
if uses.any? { |value| value.start_with?("actions/cache@") }
  abort "Persistent dependency cache must not be part of delivery"
end

resolution_steps = steps.select { |step| step["name"] == "Resolve SPM Dependencies" }
abort "SPM dependencies must be resolved exactly once" unless resolution_steps.length == 1

resolution_command = resolution_steps.fetch(0).fetch("run")
required_resolution_options = [
  "-resolvePackageDependencies",
  "-onlyUsePackageVersionsFromResolvedFile"
]
missing_resolution_options = required_resolution_options.reject do |option|
  resolution_command.include?(option)
end
unless missing_resolution_options.empty?
  abort "Missing SPM resolution options: #{missing_resolution_options.join(', ')}"
end

fastfile = File.read(fastfile_path)
unless fastfile.scan("skip_package_dependencies_resolution: true").length == 2
  abort "Validation and Archive must both reuse the resolved package graph"
end
unless fastfile.scan("skip_package_repository_fetches: true").length == 2
  abort "Validation and Archive must not fetch package repositories again"
end
unless fastfile.include?('"-skipPackageUpdates"')
  abort "Share Extension settings lookup must not fetch package repositories"
end

puts "SPM resolution contract: passed"
