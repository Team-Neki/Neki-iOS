//
//  MetaAttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import Dependencies
import FacebookCore

final class MetaAttributionRepository: AttributionRepository {
    @MainActor
    func initializeAttribution() {
        ApplicationDelegate.shared.initializeSDK()
    }
}

extension AttributionClient: DependencyKey {
    public static var liveValue: AttributionClient {
        let repository = MetaAttributionRepository()
        
        return AttributionClient(
            initializeAttribution: { await repository.initializeAttribution() }
        )
    }
}

extension DependencyValues {
    var attributionClient: AttributionClient {
        get { self[AttributionClient.self] }
        set { self[AttributionClient.self] = newValue }
    }
}
