//
//  ServerLogResponseHandler.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation

/// 보낸 배치를 응답에 따라 어떻게 할지 정합니다(Amplitude-Swift `PersistentStorageResponseHandler`).
enum ServerLogResponseHandler {
    /// - 200 D-0: 접수됐으므로 지웁니다.
    /// - 413 D-16: 반으로 나눠 다시 보냅니다. 한 건이면 진단을 남기고 지웁니다.
    /// - 400 D-01: 서버가 문제 로그를 지목하지 않으므로 반씩 나눠 한 건까지 좁힌 뒤 지웁니다.
    /// - 401·403: 토큰을 붙였다면 토큰만 빼고 바로 다시 보냅니다.
    /// - 503 D-15, 그 밖의 응답, 응답 없음: 남겨 두고 나중에 다시 보냅니다.
    static func action(
        for result: ServerLogUploadResult,
        logCount: Int,
        sentWithAuthorization: Bool
    ) -> ServerLogResponseAction {
        guard case let .responded(statusCode, _) = result else { return .retryLater }
        switch statusCode {
        case 200..<300: return .remove
        case 400, 413: return logCount > 1 ? .split : .drop
        case 401, 403: return sentWithAuthorization ? .retryWithoutAuthorization : .retryLater
        default: return .retryLater
        }
    }
}

enum ServerLogResponseAction: Equatable, Sendable {
    /// 보낸 로그를 지웁니다.
    case remove
    /// 배치를 반으로 나눠 다시 보냅니다.
    case split
    /// 한 건으로 좁혀도 받지 않는 로그라 진단을 남기고 지웁니다.
    case drop
    /// 토큰을 빼고 같은 배치를 바로 다시 보냅니다.
    case retryWithoutAuthorization
    /// 남겨 두고 나중에 다시 보냅니다.
    case retryLater
}
