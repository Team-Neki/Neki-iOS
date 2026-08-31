//
//  NetworkRequestFailureEvents.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation
import Dependencies
import os

/// 요청 실패의 발행/구독 계약입니다. 소비 완료나 화면 처리를 기다리지 않습니다.
protocol NetworkRequestFailureEvents: Sendable {
    func failures() -> AsyncStream<NetworkRequestFailure>
    func publish(_ failure: NetworkRequestFailure)
}

/// 요청 실패를 전달하는 인메모리 채널입니다. 인증 데이터 접근이나 세션 정책을 수행하지 않습니다.
///
/// 관찰 등록 이전의 실패도 전달하도록 마지막 한 건을 보관합니다. 발행은 동기적으로 끝나며,
/// NetworkProvider의 발행 순서를 유지합니다. 구독 종료 시 continuation을 제거합니다.
final class NetworkRequestFailureBroker: NetworkRequestFailureEvents {
    private struct State {
        var latestFailure: NetworkRequestFailure?
        var continuations: [UUID: AsyncStream<NetworkRequestFailure>.Continuation] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    deinit { state.withLock { Array($0.continuations.values) }.forEach { $0.finish() } }

    func failures() -> AsyncStream<NetworkRequestFailure> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<NetworkRequestFailure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        state.withLock {
            $0.continuations[id] = continuation
            if let failure = $0.latestFailure { continuation.yield(failure) }
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { $0.continuations[id] = nil }
        }
        return stream
    }

    func publish(_ failure: NetworkRequestFailure) {
        state.withLock {
            guard $0.latestFailure?.credentialRevision != failure.credentialRevision else { return }
            $0.latestFailure = failure
            $0.continuations.values.forEach { $0.yield(failure) }
        }
    }
}

private enum NetworkRequestFailureEventsKey: DependencyKey {
    static let liveValue: any NetworkRequestFailureEvents = NetworkRequestFailureBroker()
}

extension DependencyValues {
    var networkRequestFailureEvents: any NetworkRequestFailureEvents {
        get { self[NetworkRequestFailureEventsKey.self] }
        set { self[NetworkRequestFailureEventsKey.self] = newValue }
    }
}
