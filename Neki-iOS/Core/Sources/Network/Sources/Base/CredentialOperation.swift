//
//  CredentialOperation.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/14/26.
//

/// HTTP 성공 응답 이후에 적용할 자격증명 처리 정책입니다.
public enum CredentialOperation: Sendable, Equatable {
    case none
    /// 응답 데이터의 TokenContainer 계약을 통해 새 로그인 토큰을 저장합니다.
    case replaceOnSuccess
    /// 요청을 시작한 세션이 유지되는 경우에만 토큰을 삭제합니다.
    case removeOnSuccess
}
