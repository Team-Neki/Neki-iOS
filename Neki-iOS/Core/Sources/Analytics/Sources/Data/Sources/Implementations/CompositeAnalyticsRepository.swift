//
//  CompositeAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by Codex on 8/1/26.
//

import Dependencies
import Foundation

public final actor CompositeAnalyticsRepository: AnalyticsRepository {
    private let repositories: [any AnalyticsRepository]

    public init(repositories: [any AnalyticsRepository]) {
        self.repositories = repositories
    }

    public func initialize() async throws {
        for repository in repositories {
            try await repository.initialize()
        }
    }

    public func setUserSession(with userID: Int?) async {
        for repository in repositories {
            await repository.setUserSession(with: userID)
        }
    }

    public func logEvent(_ event: any AnalyticsEvent) async {
        for repository in repositories {
            await repository.logEvent(event)
        }
    }
}


// MARK: - Dependency

private enum AnalyticsRepositoryKey: DependencyKey {
    static let liveValue: any AnalyticsRepository = CompositeAnalyticsRepository(repositories: [
        FirebaseAnalyticsRepository(),
        AmplitudeAnalyticsRepository()
    ])
}

extension DependencyValues {
    public var analyticsRepository: any AnalyticsRepository {
        get { self[AnalyticsRepositoryKey.self] }
        set { self[AnalyticsRepositoryKey.self] = newValue }
    }
}
