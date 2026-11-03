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

    public func setUserSession(with userID: Int?, changedAt: Date) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.setUserSession(with: userID, changedAt: changedAt)
            }
        }
    }

    public func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.endUserSession(with: event, occurrence: occurrence)
            }
        }
    }

    public func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.logEvent(event, occurrence: occurrence)
            }
        }
    }

    public func flush() async {
        await enqueue { [repositories] in
            for repository in repositories {
                await repository.flush()
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
    /// 서버 저장소는 기기 ID와 세션 ID를 Amplitude 저장소에서 읽고, 앱 생명주기·background task·기기 정보는 APP 계층이 채운 구현에서 받습니다.
    /// - Note: Amplitude SDK 제거 시 Amplitude 저장소를 빼고, 서버 저장소의 기기 ID·세션 ID 출처를 자체 값으로 바꿉니다.
    static let liveValue: any AnalyticsRepository = {
        @Dependency(\.storedAuthTokenReader) var tokenReader
        @Dependency(\.serverLogPlatform) var platform
        let amplitude = AmplitudeAnalyticsRepository()
        let deviceSystem = platform.deviceSystem
        return CompositeAnalyticsRepository(repositories: [
            amplitude,
            ServerAnalyticsRepository(
                identity: amplitude,
                pipeline: ServerLogPipeline(
                    tokenReader: ServerLogStoredTokenReader(reader: tokenReader),
                    backgroundTask: platform.backgroundTask
                ),
                lifecycle: platform.lifecycle,
                makeContext: { ServerLogContext.current(system: await deviceSystem.read()) }
            )
        ])
    }()
}

extension DependencyValues {
    public var analyticsRepository: any AnalyticsRepository {
        get { self[AnalyticsRepositoryKey.self] }
        set { self[AnalyticsRepositoryKey.self] = newValue }
    }
}
