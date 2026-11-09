# frozen_string_literal: true

require_relative "../../fastlane/deployment_configuration"

relative_path = "Neki-iOS/APP/Sources/Resources/FirebaseConfig/Debug/GoogleService-Info.plist"
expected_path = File.join(DeploymentConfiguration::PROJECT_ROOT, relative_path)

Dir.chdir(File.join(DeploymentConfiguration::PROJECT_ROOT, "fastlane")) do
  actual_path = DeploymentConfiguration.resolve_project_path(relative_path)
  abort "Project path resolution failed: #{actual_path}" unless actual_path == expected_path
end

absolute_path = "/tmp/GoogleService-Info.plist"
resolved_absolute_path = DeploymentConfiguration.resolve_project_path(absolute_path)
abort "Absolute path changed: #{resolved_absolute_path}" unless resolved_absolute_path == absolute_path

puts "Deployment configuration path resolution: passed"
