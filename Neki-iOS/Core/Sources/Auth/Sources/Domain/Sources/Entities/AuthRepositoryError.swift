//
//  AuthRepositoryError.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

/// 전송 라이브러리나 저장소의 구체 오류를 노출하지 않는 인증 작업의 실패 사유입니다.
public enum AuthRepositoryError: Error, Sendable {
    case networkConnectionLost
    case serverError(String)
    case cancelled
    case unknown
    case unauthorized
    case userNotFound
}
