//
//  MetaAttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import Dependencies
import FacebookCore

final class MetaAttributionRepository: AttributionRepository {
    func initializeAttribution() async {
        await MainActor.run { ApplicationDelegate.shared.initializeSDK() }
    }

    func trackCompleteRegistration() async {
        await MainActor.run { AppEvents.shared.logEvent(.completedRegistration) }
    }
}

extension AttributionClient: DependencyKey {
    public static var liveValue: AttributionClient {
        let repository = MetaAttributionRepository()
        
        return AttributionClient(
            initializeAttribution: { await repository.initializeAttribution() },
            trackCompleteRegistration: { await repository.trackCompleteRegistration() }
        )
    }
}

extension DependencyValues {
    var attributionClient: AttributionClient {
        get { self[AttributionClient.self] }
        set { self[AttributionClient.self] = newValue }
    }
}
