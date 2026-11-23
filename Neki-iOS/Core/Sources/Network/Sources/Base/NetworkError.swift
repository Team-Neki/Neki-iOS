//
//  NetworkError.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation

public enum NetworkError: LocalizedError {
    case apiError(String)
    case requestEncodingError
    case responseDecodingError
    case responseError
    case notFound
    case internalServerError
    case networkFail
    case unknownError(Error)
    case invalidURLError
    /// 400 응답입니다. 서버가 본문에 보낸 결과 코드를 함께 담습니다(예: 남은 랜덤 포즈 없음 `D-09`).
    case badRequestError(resultCode: String?)
    case unauthorizedError
    case unsupportedResponseContentType
    case responseTooLarge
    
    public var errorDescription: String? {
        switch self {
        case .apiError(let message): return message
        case .requestEncodingError: return "요청 인코딩에 실패했습니다."
        case .responseDecodingError: return "응답 디코딩에 실패했습니다."
        case .responseError: return "응답 오류가 발생했습니다."
        case .notFound: return "리소스를 찾을 수 없습니다"
        case .internalServerError: return "서버 내부 오류가 발생했습니다"
        case .networkFail: return "네트워크 연결에 실패했습니다"
        case .unknownError(let error): return "알 수 없는 오류가 발생했습니다.: \(error)"
        case .invalidURLError: return "잘못된 URL입니다"
        case .badRequestError: return "잘못된 요청입니다"
        case .unauthorizedError: return "인증이 필요합니다"
        case .unsupportedResponseContentType: return "지원하지 않는 응답 형식입니다"
        case .responseTooLarge: return "응답 크기가 허용 범위를 초과했습니다"
        }
    }
}
