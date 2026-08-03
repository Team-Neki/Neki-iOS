//
//  AnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public protocol AnalyticsRepository: Sendable {
    func initialize() async throws -> Void
    func setUserSession(with userID: Int?) async -> Void
    func logEvent(_ event: any AnalyticsEvent) async -> Void
}
