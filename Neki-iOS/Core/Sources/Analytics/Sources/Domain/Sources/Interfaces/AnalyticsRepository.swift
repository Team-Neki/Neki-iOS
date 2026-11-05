//
//  AnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public protocol AnalyticsRepository: Sendable {
    func initialize() async throws -> Void
    /// 회원 ID를 바꿉니다. 회원 ID가 없어지거나 다른 회원으로 바뀌면 `changedAt`으로 새 세션을 엽니다.
    func setUserSession(with userID: Int?, changedAt: Date) async -> Void
    func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async -> Void
    func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async -> Void
    /// 쌓아 둔 이벤트를 지금 보냅니다.
    func flush() async -> Void
}
