//
//  AppDiagnostics.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import Foundation
import UserNotifications

public struct AppDiagnostics: Equatable, Sendable {
    public let userSession: Section
    public let app: Section
    public let firebase: Section
    public let pushNotification: Section

    public static let empty = Self(
        userSession: .init(title: "사용자 세션", rows: []),
        app: .init(title: "앱", rows: []),
        firebase: .init(title: "Firebase", rows: []),
        pushNotification: .init(title: "푸시 알림", rows: [])
    )

    public var sections: [Section] {
        [userSession, app, firebase, pushNotification]
    }

    public struct Section: Equatable, Identifiable, Sendable {
        public var id: String { title }
        public let title: String
        public let rows: [Row]
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public var id: String { title }
        public let title: String
        public let value: String
    }

    public enum TokenStatus: Equatable, Sendable {
        case missing
        case available(value: String)

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
        bundleIdentifier: String,
        appVersion: String,
        buildNumber: String,
        distributionChannel: String,
        firebaseProjectID: String,
        firebaseApplicationID: String,
        firebaseSenderID: String,
        firebaseBundleID: String,
        apnsEnvironment: String,
        apnsTokenStatus: TokenStatus,
        fcmTokenStatus: TokenStatus,
        notificationAuthorizationStatus: UNAuthorizationStatus
    ) {
        self.userSession = Self.userSessionSection(from: userSessionStatus)
        self.app = .init(
            title: "앱",
            rows: [
                .init(title: "Bundle ID", value: bundleIdentifier),
                .init(title: "App Version", value: appVersion),
                .init(title: "Build Number", value: buildNumber),
                .init(title: "Distribution", value: distributionChannel)
            ]
        )
        self.firebase = .init(
            title: "Firebase",
            rows: [
                .init(title: "Project ID", value: firebaseProjectID),
                .init(title: "App ID", value: firebaseApplicationID),
                .init(title: "Sender ID", value: firebaseSenderID),
                .init(title: "Bundle ID", value: firebaseBundleID)
            ]
        )
        self.pushNotification = .init(
            title: "푸시 알림",
            rows: [
                .init(title: "APNs Environment", value: apnsEnvironment),
                .init(title: "APNs Token", value: apnsTokenStatus.description),
                .init(title: "FCM Token", value: fcmTokenStatus.description),
                .init(title: "OS Notification", value: notificationAuthorizationStatus.diagnosticsDescription)
            ]
        )
    }

    static func userSessionSection(from status: UserSessionStatus) -> Section {
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
                ]
            )

        case .signedOut:
            return .init(
                title: "사용자 세션",
                rows: [
                    .init(title: "Session Status", value: "signedOut")
                ]
            )

        case .expired:
            return .init(
                title: "사용자 세션",
                rows: [
                    .init(title: "Session Status", value: "expired")
                ]
            )
        }
    }
}

private extension Bool {
    var diagnosticsDescription: String {
        self ? "true" : "false"
    }
}

public extension UNAuthorizationStatus {
    var diagnosticsDescription: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}
