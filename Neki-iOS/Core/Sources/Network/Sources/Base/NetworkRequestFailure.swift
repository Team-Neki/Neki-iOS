//
//  NetworkRequestFailure.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

import Foundation

/// 재시도로 복구되지 않은 요청 실패입니다. 로그인 상태나 토큰 원문은 전달하지 않습니다.
struct NetworkRequestFailure: Sendable {
    enum Reason: Sendable {
        case credentialsUnavailable
        case unauthorized
    }

    /// 요청에 사용한 저장 데이터의 버전입니다. 소비자가 오래된 실패인지 판단할 때 사용합니다.
    let credentialRevision: UUID
    let reason: Reason
}
