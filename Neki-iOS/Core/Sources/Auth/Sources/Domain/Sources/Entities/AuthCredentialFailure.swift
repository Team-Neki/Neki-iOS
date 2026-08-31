//
//  AuthCredentialFailure.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation

/// 요청을 인증할 수 없었던 자격증명입니다. 사용자 세션을 만료시킬지는 Client가 결정합니다.
public struct AuthCredentialFailure: Sendable {
    public enum Reason: Sendable {
        case missingCredentials
        case rejectedCredentials
    }

    public enum RemovalResult: Sendable {
        case removed
        /// 새 로그인 또는 재발급으로 다른 자격증명이 저장되어 삭제하지 않았습니다.
        case superseded
        /// 일치하는 자격증명을 확인했으나 저장소에서 제거하지 못했습니다.
        case storageFailure
    }

    let revision: UUID
    let reason: Reason
}
