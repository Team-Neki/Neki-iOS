//
//  AppRouterTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 8/1/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct AppRouterTests {
    @Test("필수약관 동의 사용자는 메인 화면으로 이동한다")
    func agreedRequiredTerms_routesToMainTab() {
        var state = AppCoordinator.State()
        let user = makeUser(allRequiredTermsAgreed: true)

        _ = AppRouter().navigateToNextScreen(
            state: &state,
            sessionStatus: .signedIn(user),
            isMarketingConsentAlertEligible: { _ in false }
        )

        guard case .mainTab = state.route else {
            Issue.record("필수약관 동의 사용자가 메인 화면으로 이동하지 않았습니다.")
            return
        }
    }

    @Test("필수약관 미동의 사용자는 약관동의화면으로 이동한다")
    func unagreedRequiredTerms_routesToTermsAgreement() {
        var state = AppCoordinator.State()
        let user = makeUser(allRequiredTermsAgreed: false)

        _ = AppRouter().navigateToNextScreen(
            state: &state,
            sessionStatus: .signedIn(user),
            isMarketingConsentAlertEligible: { _ in false }
        )

        guard case .termsAgreement = state.route else {
            Issue.record("필수약관 미동의 사용자가 약관동의화면으로 이동하지 않았습니다.")
            return
        }
    }
}

private extension AppRouterTests {
    func makeUser(allRequiredTermsAgreed: Bool) -> User {
        User(
            id: 1,
            nickname: "테스트 사용자",
            email: nil,
            profileImageURL: nil,
            providerType: .local,
            allRequiredTermsAgreed: allRequiredTermsAgreed
        )
    }
}
