//
//  ServerLogSessionTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogSessionTests {
    private let start: Int64 = 1_793_610_000_000

    @Test("첫 이벤트는 그 시각으로 새 세션을 열고 순번 1을 매긴다")
    func number_firstEvent_startsSession() {
        var session = ServerLogSession()

        let result = session.number(eventAt: start, inForeground: true, sessionID: start)

        #expect(result.computedSessionID == start)
        #expect(result.sequenceNumber == 1)
    }

    @Test("포그라운드에서는 만료 시간이 지나도 같은 세션을 잇는다")
    func number_inForeground_keepsSessionPastTimeout() {
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: true, sessionID: start)

        let result = session.number(eventAt: start + 3_600_000, inForeground: true, sessionID: start)

        #expect(result.computedSessionID == start)
        #expect(result.sequenceNumber == 2)
    }

    @Test("백그라운드 이벤트는 마지막 시각에서 5분 안이면 잇고, 5분이 되면 새 세션을 연다")
    func number_inBackground_followsTimeout() {
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: false, sessionID: start)

        let near = start + 299_999
        let nearResult = session.number(eventAt: near, inForeground: false, sessionID: start)
        let far = near + 300_000
        let farResult = session.number(eventAt: far, inForeground: false, sessionID: far)

        #expect(nearResult.computedSessionID == start)
        #expect(farResult.computedSessionID == far)
    }

    @Test("포그라운드에 오래 머문 뒤에도 백그라운드에 들어간 시각부터 5분을 센다")
    func enterForeground_measuresFromBackgroundEntry() {
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: true, sessionID: start)
        let firstBackground = start + 3_600_000

        session.exitForeground(at: firstBackground)
        session.enterForeground(at: firstBackground + 240_000)
        let sessionAfterShortBackground = session.sessionID

        let secondBackground = firstBackground + 300_000
        session.exitForeground(at: secondBackground)
        session.enterForeground(at: secondBackground + 360_000)

        #expect(sessionAfterShortBackground == start)
        #expect(session.sessionID == secondBackground + 360_000)
    }

    @Test("서버로 보내는 세션 ID가 바뀌면 순번을 1부터 다시 센다")
    func number_restartsSequenceForNewSentSession() {
        var session = ServerLogSession()

        let firstSession = (0..<3).map { offset in
            session.number(eventAt: start + Int64(offset), inForeground: true, sessionID: start).sequenceNumber
        }
        let nextSession = session.number(eventAt: start + 10, inForeground: true, sessionID: start + 10).sequenceNumber

        #expect(firstSession == [1, 2, 3])
        #expect(nextSession == 1)
    }

    @Test("로그인은 세션을 잇고, 로그아웃하거나 다른 회원으로 바뀌면 새 세션을 연다")
    func updateUserID_startsSessionWhenUserLeaves() {
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: true, sessionID: start)

        let signedIn = session.updateUserID("1", at: start + 1_000)
        let sessionAfterSignIn = session.sessionID
        let switched = session.updateUserID("2", at: start + 2_000)
        let sessionAfterSwitch = session.sessionID
        let signedOut = session.updateUserID(nil, at: start + 3_000)
        let sessionAfterSignOut = session.sessionID
        let signedOutAgain = session.updateUserID(nil, at: start + 4_000)

        #expect(signedIn == false)
        #expect(sessionAfterSignIn == start)
        #expect(switched)
        #expect(sessionAfterSwitch == start + 2_000)
        #expect(signedOut)
        #expect(sessionAfterSignOut == start + 3_000)
        #expect(signedOutAgain == false)
        #expect(session.sessionID == start + 3_000)
        #expect(session.userID == nil)
    }

    @Test("시계가 뒤로 가도 SDK처럼 같은 세션을 잇는다")
    func number_whenClockGoesBack_keepsSession() {
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: false, sessionID: start)

        let result = session.number(eventAt: start - 600_000, inForeground: false, sessionID: start)

        #expect(result.computedSessionID == start)
        #expect(session.lastEventTime == start - 600_000)
    }

    @Test("저장한 상태를 재실행 때 복원해 5분 규칙을 이어서 적용한다")
    func store_restoresSessionAfterRelaunch() throws {
        let suiteName = "ServerLogSessionTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerLogSessionStore(defaults: defaults)
        var session = ServerLogSession()
        _ = session.number(eventAt: start, inForeground: true, sessionID: start)
        session.updateUserID("1", at: start)
        session.exitForeground(at: start + 10_000)

        store.save(session)
        var restored = store.load()
        let result = restored.number(eventAt: start + 250_000, inForeground: false, sessionID: start)

        #expect(store.load() == session)
        #expect(restored.userID == "1")
        #expect(result.computedSessionID == start)
        #expect(result.sequenceNumber == 2)
    }

    @Test("저장된 상태가 없으면 세션 없이 시작한다")
    func store_withoutSavedState_returnsEmptySession() throws {
        let suiteName = "ServerLogSessionTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ServerLogSessionStore(defaults: defaults).load() == ServerLogSession())
    }
}
