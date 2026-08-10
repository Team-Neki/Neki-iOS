//
//  CompositeAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/1/26.
//

import Dependencies
import Foundation

public final actor CompositeAnalyticsRepository: AnalyticsRepository {
    private let repositories: [any AnalyticsRepository]
    private var pendingOperation: Task<Void, Never>?
    private var operationGeneration = 0

    public init(repositories: [any AnalyticsRepository]) {
        self.repositories = repositories
    }

    public func initialize() async throws {
        for repository in repositories {
            try await repository.initialize()
        }
    }

    public func setUserSession(with userID: Int?) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.setUserSession(with: userID)
            }
        }
    }

    public func endUserSession(with event: any AnalyticsEvent) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.endUserSession(with: event)
            }
        }
    }

    public func logEvent(_ event: any AnalyticsEvent) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.logEvent(event)
            }
        }
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) async {
        operationGeneration += 1
        let generation = operationGeneration
        let previousOperation = pendingOperation
        let operationTask = Task {
            await previousOperation?.value
            await operation()
        }
        pendingOperation = operationTask
        await operationTask.value
        if operationGeneration == generation { pendingOperation = nil }
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
