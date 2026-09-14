//
//  NetworkCredentialFailure.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation

/// 재시도로 복구되지 않은 자격증명 실패입니다. 로그인 상태나 토큰 원문은 전달하지 않습니다.
struct NetworkCredentialFailure: Error {
    enum Reason: Sendable {
        case credentialsUnavailable
        case unauthorized
    }

    /// 실패 처리 후의 세션 식별자입니다. 이후 로그인으로 바뀌었다면 이 실패는 폐기합니다.
    let credentialGeneration: UUID
    let reason: Reason
}
