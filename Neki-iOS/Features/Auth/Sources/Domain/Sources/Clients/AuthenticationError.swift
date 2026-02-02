//
//  AuthenticationError.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum AuthClientError: Error {
    case cancelled // 사용자가 인증 과정을 이탈함
    case sessionExpired // 토큰 만료로 인해 재로그인이 필요함
    case networkConnectionLost // 인터넷 연결 끊김
    case serverError(String) // 서버 내부 오류, etc
    case invalidClientToken // 클라이언트 내부 오류
    case unknown
}
