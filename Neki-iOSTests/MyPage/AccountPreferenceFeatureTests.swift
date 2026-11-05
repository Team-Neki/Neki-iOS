//
//  AccountPreferenceFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct AccountPreferenceFeatureTests {
    @Test("로그아웃은 요청하기 전에 남기고, 로그아웃에 성공한 뒤 사용자를 해제한다")
    func logoutButtonTapped_logsBeforeRequestAndClearsUserAfterSuccess() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) {
            $0.authClient.signOut = { records.withValue { $0.append("signOut") } }
        }

        await store.send(.logoutButtonTapped).finish()

        #expect(records.value == ["mypage_logout", "signOut", "user nil"])
    }

    @Test("로그아웃 요청이 실패해도 로그아웃을 남기고, 사용자는 해제하지 않는다")
    func logoutButtonTapped_whenRequestFails_logsLogoutAndKeepsUser() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) {
            $0.authClient.signOut = { throw LogoutFailure() }
        }

        await store.send(.logoutButtonTapped).finish()

        #expect(records.value == ["mypage_logout"])
        #expect(store.isLoading == false)
    }
}


// MARK: - Helpers

private extension AccountPreferenceFeatureTests {
    /// 보낸 분석 이벤트와 사용자 지정을 `records`에 차례로 모읍니다.
    ///
    /// `AccountPreferenceFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        records: LockIsolated<[String]>,
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void
    ) -> StoreOf<AccountPreferenceFeature> {
        Store(initialState: AccountPreferenceFeature.State()) {
            AccountPreferenceFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                records.withValue { $0.append(event.name.value) }
            }
            $0.analyticsClient.setUserSession = { userID in
                records.withValue { $0.append("user \(userID.map(String.init) ?? "nil")") }
            }
            updateDependencies(&$0)
        }
    }
}

private struct LogoutFailure: Error {}
