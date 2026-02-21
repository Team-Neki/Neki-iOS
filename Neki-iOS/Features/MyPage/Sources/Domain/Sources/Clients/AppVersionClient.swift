//
//  AppVersionClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
struct AppVersionClient {
    typealias VersionResult = (current: AppVersion, latest: AppVersion, status: AppUpdateStatus)
    
    var checkVersion: @Sendable () async throws -> VersionResult
    var currentVersion: @Sendable () -> AppVersion = { .init(major: .zero, minor: .zero, revision: .zero) }
}

extension AppVersionClient: DependencyKey {
    static var liveValue: AppVersionClient = {
        @Dependency(\.appVersionRepository) var appVersionRepository
        
        let fetchLocalVersion: @Sendable () -> AppVersion = {
            let localVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            return AppVersion(value: localVersionString)
        }
        
        return AppVersionClient {
            let (minimumVersion, latestVersion) = try await appVersionRepository.fetchVersionInfo()
            let currentVersion = fetchLocalVersion()
            
            guard currentVersion >= minimumVersion else { return (currentVersion, latestVersion, .mustUpdate) }
            guard currentVersion >= latestVersion else { return (currentVersion, latestVersion, .optionalUpdate) }
            return (currentVersion, latestVersion, .upToDate)
        } currentVersion: {
            return fetchLocalVersion()
        }
    }()
}

extension DependencyValues {
    var appVersionClient: AppVersionClient {
        get { self[AppVersionClient.self] }
        set { self[AppVersionClient.self] = newValue }
    }
}
