//
//  ServerLogSession.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation

/// 서버 로그의 세션과 순번 상태
/// - Note: 서버로 보내는 세션 ID는 Amplitude SDK 값이고, 순번은 그 세션 안에서 1부터 셉니다. 세션 규칙은 SDK(Amplitude-Swift `Sessions`)와 같게 따로 계산해, SDK 값과 맞는지 비교하는 데 씁니다.
/// - Note: Amplitude SDK 제거 시 자체 계산한 세션 ID를 서버로 보내고 SDK 값과의 비교를 지웁니다. 바꾼 버전의 첫 실행에서는 Amplitude가 저장해 둔 `previous_session_id`·`last_event_time`을 읽어 세션을 잇습니다.
struct ServerLogSession: Codable, Equatable, Sendable {
    /// SDK와 같은 세션 만료 시간(5분)
    static let timeout: Int64 = 300_000

    /// 자체 계산한 세션 ID(세션 시작 시각, epoch ms). 세션이 없으면 -1
    private(set) var sessionID: Int64 = -1
    /// 마지막 이벤트 또는 백그라운드 진입 시각(epoch ms). 없으면 -1
    private(set) var lastEventTime: Int64 = -1
    /// 마지막으로 순번을 매긴 세션 ID(서버로 보낸 값)
    private(set) var numberedSessionID: Int64 = -1
    /// `numberedSessionID` 세션에서 마지막으로 쓴 순번
    private(set) var lastSequenceNumber = 0
    /// 마지막으로 알려진 회원 ID. Amplitude처럼 재실행해도 유지합니다.
    private(set) var userID: String?

    /// 이벤트 한 건의 순번을 정하고, 같은 시각으로 자체 계산한 세션 ID를 돌려줍니다.
    mutating func number(
        eventAt timestamp: Int64,
        inForeground: Bool,
        sessionID sentSessionID: Int64
    ) -> (sequenceNumber: Int, computedSessionID: Int64) {
        startNewSessionIfNeeded(at: timestamp, inForeground: inForeground)
        if numberedSessionID != sentSessionID {
            numberedSessionID = sentSessionID
            lastSequenceNumber = 0
        }
        lastSequenceNumber += 1
        return (lastSequenceNumber, sessionID)
    }

    /// 포그라운드로 돌아올 때(SDK `onEnterForeground`). SDK처럼 돌아오기 전 상태로 판정합니다.
    mutating func enterForeground(at timestamp: Int64) {
        startNewSessionIfNeeded(at: timestamp, inForeground: false)
    }

    /// 백그라운드로 갈 때(SDK `onExitForeground`)
    mutating func exitForeground(at timestamp: Int64) {
        lastEventTime = timestamp
    }

    /// 회원 ID를 바꿉니다. 로그인은 세션을 잇고, 회원 ID가 없어지거나 다른 회원으로 바뀌면 새 세션을 엽니다(#383 4.4).
    /// - Returns: 새 세션을 열었는지
    @discardableResult
    mutating func updateUserID(_ userID: String?, at timestamp: Int64) -> Bool {
        defer { self.userID = userID }
        guard let currentUserID = self.userID, currentUserID != userID else { return false }
        startNewSession(at: timestamp)
        return true
    }

    private mutating func startNewSessionIfNeeded(at timestamp: Int64, inForeground: Bool) {
        if sessionID >= 0, inForeground || timestamp - lastEventTime < Self.timeout {
            lastEventTime = timestamp
        } else {
            startNewSession(at: timestamp)
        }
    }

    private mutating func startNewSession(at timestamp: Int64) {
        sessionID = timestamp
        lastEventTime = timestamp
    }
}

/// 세션 상태를 UserDefaults에 저장하고 재실행 때 복원합니다(SDK와 같은 방식).
struct ServerLogSessionStore {
    private static let key = "ServerLogSession"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ServerLogSession {
        guard let data = defaults.data(forKey: Self.key),
              let session = try? JSONDecoder().decode(ServerLogSession.self, from: data)
        else { return ServerLogSession() }
        return session
    }

    func save(_ session: ServerLogSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
