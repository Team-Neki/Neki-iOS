//
//  AuthCredentialFailure.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation

/// 인증 복구 실패가 발생한 세션입니다. 현재 세션에 해당하는지 확인한 후 만료시킵니다.
public struct AuthCredentialFailure: Sendable {
    public enum Reason: Sendable {
        case missingCredentials
        case rejectedCredentials
    }

    public let generation: UUID
    public let reason: Reason

    public init(generation: UUID, reason: Reason) {
        self.generation = generation
        self.reason = reason
    }
}
