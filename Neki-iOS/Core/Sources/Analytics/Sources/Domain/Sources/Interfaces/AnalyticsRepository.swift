//
//  AnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public protocol AnalyticsRepository: Sendable {
    func setUserSession(with userID: Int?) async -> Void
    func logEvent(_ event: AnalyticsEvent) async -> Void
}
