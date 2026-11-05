//
//  AppDiagnostics.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/7/26.
//

import Foundation

public struct AppDiagnostics: Equatable, Sendable {
    public let sections: [Section]

    public static let empty = Self(
        sections: [
            .init(title: "사용자 세션", rows: []),
            .init(title: "앱", rows: []),
            .init(title: "Firebase", rows: []),
            .init(title: "푸시 알림", rows: [])
        ]
    )

    public init(sections: [Section]) {
        self.sections = sections
    }

    public struct Section: Equatable, Identifiable, Sendable {
        public var id: String { title }
        public let title: String
        public let rows: [Row]

        public init(title: String, rows: [Row]) {
            self.title = title
            self.rows = rows
        }
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public var id: String { title }
        public let title: String
        public let value: String

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    public enum TokenStatus: Equatable, Sendable {
        case missing
        case available(value: String)

        static func from(_ token: String?) -> Self {
            guard let token, token.isEmpty == false else { return .missing }
            return .available(value: token)
        }

        public var description: String {
            switch self {
            case .missing: return "missing"
            case let .available(value): return value
            }
        }
    }
}

extension AppDiagnostics {
    public init(
        userSessionStatus: UserSessionStatus,
        authTokens: AuthTokens?,
        appSection: Section,
        firebaseSection: Section,
        apnsEnvironment: String,
        apnsTokenStatus: TokenStatus,
        fcmTokenStatus: TokenStatus,
        notificationAuthorizationDescription: String,
        referenceDate: Date
    ) {
        self.sections = [
            Self.userSessionSection(from: userSessionStatus, authTokens: authTokens, referenceDate: referenceDate),
            appSection,
            firebaseSection,
            .init(
                title: "푸시 알림",
                rows: [
                    .init(title: "APNs Environment", value: apnsEnvironment),
                    .init(title: "APNs Token", value: apnsTokenStatus.description),
                    .init(title: "FCM Token", value: fcmTokenStatus.description),
                    .init(title: "OS Notification", value: notificationAuthorizationDescription)
                ]
            )
        ]
    }

    static func userSessionSection(
        from status: UserSessionStatus,
        authTokens: AuthTokens?,
        referenceDate: Date
    ) -> Section {
        switch status {
        case let .signedIn(user):
            return .init(
                title: "사용자 세션",
                rows: [
                    .init(title: "Session Status", value: "signedIn"),
                    .init(title: "User ID", value: "\(user.id)"),
                    .init(title: "Nickname", value: user.nickname),
                    .init(title: "Email", value: user.email ?? "-"),
                    .init(title: "Provider", value: user.providerType.rawValue),
                    .init(title: "Profile Image URL", value: user.profileImageURL?.absoluteString ?? "-"),
                    .init(title: "Required Terms Agreed", value: user.allRequiredTermsAgreed.diagnosticsDescription),
                    .init(title: "Marketing Term Agreed", value: user.marketingTermAgreed.diagnosticsDescription),
                    .init(title: "Push Notification Agreed", value: user.pushNotificationAgreed.diagnosticsDescription)
                ] + authTokenRows(from: authTokens, referenceDate: referenceDate)
            )

        case .signedOut:
            return .init(
                title: "사용자 세션",
                rows: [
                    .init(title: "Session Status", value: "signedOut")
                ] + authTokenRows(from: authTokens, referenceDate: referenceDate)
            )

        case .expired:
            return .init(
                title: "사용자 세션",
                rows: [
                    .init(title: "Session Status", value: "expired")
                ] + authTokenRows(from: authTokens, referenceDate: referenceDate)
            )
        }
    }

    static func authTokenRows(from tokens: AuthTokens?, referenceDate: Date) -> [Row] {
        guard let tokens else {
            return [
                .init(title: "Access Token", value: "missing"),
                .init(title: "Refresh Token", value: "missing")
            ]
        }

        return [
            .init(title: "Access Token", value: tokens.accessToken),
            .init(title: "Refresh Token", value: tokens.refreshToken),
            .init(title: "Token Expired At", value: tokens.expiredAt.formatted(date: .numeric, time: .standard)),
            .init(title: "Token Refresh Needed", value: tokens.isRefreshNeeded(at: referenceDate).diagnosticsDescription)
        ]
    }
}

private extension Bool {
    var diagnosticsDescription: String {
        self ? "true" : "false"
    }
}
