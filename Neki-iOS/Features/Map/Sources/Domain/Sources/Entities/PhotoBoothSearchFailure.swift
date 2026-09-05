//
//  PhotoBoothSearchFailure.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/28/26.
//

import Foundation

/// 검색 요청이 실패한 원인입니다.
public enum PhotoBoothSearchFailure: Equatable, Sendable {
    /// 네트워크에 연결할 수 없어 실패했습니다.
    case network
    /// 그 밖의 이유로 실패했습니다.
    case unknown

    /// 요청에서 던져진 오류를 실패 원인으로 변환합니다.
    public init(_ error: Error) {
        self = Self.isNetworkFailure(error) ? .network : .unknown
    }

    /// 연결 문제로 발생한 오류인지 판정합니다.
    ///
    /// `DefaultNetworkProvider`는 연결 실패 `URLError`를 `NetworkError.unknownError`로 감싸 던지므로
    /// 감싸인 오류까지 따라 들어가 확인합니다.
    private static func isNetworkFailure(_ error: Error) -> Bool {
        switch error {
        case let urlError as URLError:
            return connectionLostCodes.contains(urlError.code)

        case let networkError as NetworkError:
            switch networkError {
            case .networkFail: return true
            case .unknownError(let underlyingError): return isNetworkFailure(underlyingError)
            default: return false
            }

        default:
            return false
        }
    }

    /// 연결이 끊긴 상황으로 취급할 `URLError` 코드입니다.
    ///
    /// - Note: QR 코드 스캐너의 판정 기준과 동일하게 맞췄습니다.
    private static let connectionLostCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost
    ]
}
