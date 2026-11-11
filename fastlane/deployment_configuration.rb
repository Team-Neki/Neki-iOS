# frozen_string_literal: true

module DeploymentConfiguration
  TEAM_ID = "P85DW78LYM"
  PROJECT_ROOT = File.expand_path("..", __dir__)
  PROJECT = File.join(PROJECT_ROOT, "Neki-iOS.xcodeproj")
  IOS_DESTINATION = "generic/platform=iOS"
  APP_TARGET = "Neki-iOS"
  SHARE_EXTENSION_TARGET = "NekiShareExtension"

  CONFIGURATIONS = {
    "development" => {
      app_identifier: "com.OneTen.Neki-iOS-dev",
      share_extension_app_identifier: "com.OneTen.Neki-iOS-dev.Share-Extension",
      app_target: APP_TARGET,
      share_extension_target: SHARE_EXTENSION_TARGET,
      scheme: "Neki-iOS.Dev",
      build_configuration: "Staging"
    },
    "production" => {
      app_identifier: "com.OneTen.Neki-iOS",
      share_extension_app_identifier: "com.OneTen.Neki-iOS.Share-Extension",
      app_target: APP_TARGET,
      share_extension_target: SHARE_EXTENSION_TARGET,
      scheme: "Neki-iOS",
      build_configuration: "Release"
    }
  }.freeze

  def self.resolve_project_path(path)
    File.expand_path(path, PROJECT_ROOT)
  end

  def self.fetch(target)
    CONFIGURATIONS.fetch(target) do
      raise ArgumentError, "Unsupported deployment target: #{target}"
    end
  end
end
