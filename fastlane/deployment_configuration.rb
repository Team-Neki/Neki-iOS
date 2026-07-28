# frozen_string_literal: true

module DeploymentConfiguration
  TEAM_ID = "P85DW78LYM"
  PROJECT = "Neki-iOS.xcodeproj"

  CONFIGURATIONS = {
    "development" => {
      app_identifier: "com.OneTen.Neki-iOS-dev",
      share_extension_app_identifier: "com.OneTen.Neki-iOS-dev.Share-Extension",
      scheme: "Neki-iOS.Dev",
      build_configuration: "Staging"
    },
    "production" => {
      app_identifier: "com.OneTen.Neki-iOS",
      share_extension_app_identifier: "com.OneTen.Neki-iOS.Share-Extension",
      scheme: "Neki-iOS",
      build_configuration: "Release"
    }
  }.freeze

  def self.fetch(target)
    CONFIGURATIONS.fetch(target) do
      raise ArgumentError, "Unsupported deployment target: #{target}"
    end
  end
end
