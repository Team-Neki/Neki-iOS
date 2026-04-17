//
//  DefaultAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation
import Dependencies

public final actor DefaultAnalyticsRepository {
    private let service: AnalyticsService
    
    public init(service: AnalyticsService) { self.service = service }
}


// MARK: - DefaultAnalyticsRepository + AnalyticsRepository

extension DefaultAnalyticsRepository: AnalyticsRepository {
    public func setUserSession(with userID: Int?) async {
        let userID = userID.map { String($0) }
        await service.setUserID(userID)
    }
    
    public func logEvent(_ event: any AnalyticsEvent) async {
        let eventName = event.name.value
        var parsedParameters: [String: Any]?
        
        if let parameters = event.parameters {
            parsedParameters = [:]
            for (key, value) in parameters {
                parsedParameters?[key.name] = value
            }
        }
        await service.sendEvent(name: eventName, parameters: parsedParameters)
    }
}


// MARK: - Dependency

extension DefaultAnalyticsRepository: DependencyKey {
    public static var liveValue: AnalyticsRepository = {
        let service = FirebaseAnalyticsService()
        return DefaultAnalyticsRepository(service: service)
    }()
}

extension DependencyValues {
    public var analyticsRepository: AnalyticsRepository {
        get { self[DefaultAnalyticsRepository.self] }
        set { self[DefaultAnalyticsRepository.self] = newValue }
    }
}
