//
//  AnalyticsEventOccurrence.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation

/// 이벤트 한 건이 발생한 기록
/// - Note: 같은 발생은 모든 저장소에 같은 ID와 시각으로 남깁니다. Amplitude의 `insert_id`·`time`과 서버 로그의 `eventId`·`occurredAt`을 맞춰 두 경로를 이벤트 단위로 대조하기 위함입니다.
public struct AnalyticsEventOccurrence: Sendable, Equatable {
    /// 소문자 UUID 문자열
    public let id: String
    /// 발생 시각(epoch milliseconds). Amplitude SDK와 같이 밀리초 아래는 버립니다.
    public let occurredAtMilliseconds: Int64

    public init(id: UUID, occurredAt: Date) {
        self.id = id.uuidString.lowercased()
        self.occurredAtMilliseconds = Int64(occurredAt.timeIntervalSince1970 * 1000)
    }
}
