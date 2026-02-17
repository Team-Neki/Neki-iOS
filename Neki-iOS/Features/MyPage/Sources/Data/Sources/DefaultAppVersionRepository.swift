//
//  DefaultAppVersionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation
import Dependencies
import DependenciesMacros

final actor DefaultAppVersionRepository {
    private var minimumVersion: AppVersion?
    private var latestVersion: AppVersion?
    
    @Dependency(\.networkProvider) private var networkProvider
    
    init() {}
}


// MARK: - DefaultAppVersionRepository + AppVersionRepository

extension DefaultAppVersionRepository: AppVersionRepository {
    func fetchVersionInfo() async throws -> (minimumVersion: AppVersion, latestVersion: AppVersion) {
        if let minimumVersion, let latestVersion { return (minimumVersion, latestVersion) }
        
        let platform: String = "ios"
        let endpoint = MyPageEndpoint.fetchAppVersion(platform: platform)
        let responseDTO: BaseResponseDTO<FetchAppVersionDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
        let minimumVersionEntity = AppVersion(value: data.minimumVersion)
        let latestVersionEntity = AppVersion(value: data.currentVersion)
        
        self.minimumVersion = minimumVersionEntity
        self.latestVersion = latestVersionEntity
        
        return (minimumVersionEntity, latestVersionEntity)
    }
}


private enum AppVersionRepositoryKey: DependencyKey {
    static var liveValue: AppVersionRepository = DefaultAppVersionRepository()
}

extension DependencyValues {
    var appVersionRepository: AppVersionRepository {
        get { self[AppVersionRepositoryKey.self] }
        set { self[AppVersionRepositoryKey.self] = newValue }
    }
}
