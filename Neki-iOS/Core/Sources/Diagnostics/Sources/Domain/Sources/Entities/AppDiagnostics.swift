//
//  AppDiagnostics.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import Foundation
import UserNotifications

public struct AppDiagnostics: Equatable, Sendable {
    public let app: Section
    public let firebase: Section
    public let pushNotification: Section

    public static let empty = Self(
        app: .init(title: "앱", rows: []),
        firebase: .init(title: "Firebase", rows: []),
        pushNotification: .init(title: "푸시 알림", rows: [])
    )

    public var sections: [Section] {
        [app, firebase, pushNotification]
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
