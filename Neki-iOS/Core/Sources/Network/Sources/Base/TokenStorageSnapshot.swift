//
//  TokenStorageSnapshot.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation

/// 토큰과 변경 식별자를 같은 임계 구역에서 읽은 결과입니다.
public struct TokenStorageSnapshot: Sendable {
    public let tokens: AuthTokens?
    /// 로그인/삭제 때 변경되며, 토큰 재발급에서는 유지됩니다.
    public let generation: UUID
    /// 저장 데이터가 바뀔 때마다 변경됩니다. 조건부 교체/삭제에 사용합니다.
    public let revision: UUID

    public init(tokens: AuthTokens?, generation: UUID, revision: UUID) {
        self.tokens = tokens
        self.generation = generation
        self.revision = revision
    }
}
