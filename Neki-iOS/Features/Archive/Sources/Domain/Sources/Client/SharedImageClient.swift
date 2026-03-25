//
//  SharedImageClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/20/26.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct SharedImageClient {
    public var fetchSharedImageURLs: @Sendable (_ appGroupID: String) async throws -> [URL]
    public var clearSharedImages: @Sendable (_ appGroupID: String) async throws -> Void
}

extension SharedImageClient: DependencyKey {
    public static let liveValue: SharedImageClient = {
        @Dependency(\.sharedImageRepository) var sharedImageRepository
        
        return SharedImageClient { appGroupID in
            try await sharedImageRepository.fetchSharedImageURLs(appGroupID: appGroupID)
        } clearSharedImages: { appGroupID in
            try await sharedImageRepository.clearSharedImages(appGroupID: appGroupID)
        }
    }()
}

extension DependencyValues {
    public var sharedImageClient: SharedImageClient {
        get { self[SharedImageClient.self] }
        set { self[SharedImageClient.self] = newValue }
    }
}
