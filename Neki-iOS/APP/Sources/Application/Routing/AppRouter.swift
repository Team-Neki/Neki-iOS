//
//  AppRouter.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import ComposableArchitecture
import Foundation

struct AppRouter {
    private let linkParser: any AppRouteLinkParsing

    init(linkParser: any AppRouteLinkParsing = AppRouteLinkParser()) {
        self.linkParser = linkParser
    }

    func handleOpenURL(
        state: inout AppCoordinator.State,
        url: URL
    ) -> Effect<AppCoordinator.Action> {
        guard let routeRequest = routeRequest(from: url) else { return .none }
        state.pendingRouteRequest = routeRequest
        return executePendingRouteIfNeeded(state: &state)
    }

    func navigateToNextScreen(
        state: inout AppCoordinator.State,
        sessionStatus: UserSessionStatus,
        shouldPresentMarketingConsentAlert: Bool = false,
        isMarketingConsentAlertEligible: (User) -> Bool
    ) -> Effect<AppCoordinator.Action> {
        switch sessionStatus {
        case let .signedIn(user):
            guard user.allRequiredTermsAgreed else {
                state.route = .termsAgreement(.init())
                return .none
            }

            state.route = .mainTab(.init(
                shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
                    || isMarketingConsentAlertEligible(user)
            ))
            return .merge(
                .send(.checkPushNotificationAuthorization),
                executePendingRouteIfNeeded(state: &state)
            )

        case .signedOut, .expired:
            if state.hasSeenOnboarding {
                state.route = .auth(.init())
                if case .expired = sessionStatus {
                    state.toastItem = .init("다시 로그인 해주세요.")
                }
            } else {
                state.route = .onboarding(.init())
            }
            return .none
        }
    }

    func executePendingRouteIfNeeded(
        state: inout AppCoordinator.State
    ) -> Effect<AppCoordinator.Action> {
        guard let request = state.pendingRouteRequest else { return .none }
        guard case .mainTab = state.route else { return .none }
        state.pendingRouteRequest = nil
        return route(to: request)
    }

    func route(
        to request: AppRouteRequest
    ) -> Effect<AppCoordinator.Action> {
        .send(.route(.mainTab(.route(request))))
    }

    private func routeRequest(from url: URL) -> AppRouteRequest? {
        try? linkParser.parse(url)
    }
}
