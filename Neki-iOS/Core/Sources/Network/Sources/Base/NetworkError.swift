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
    case badRequestError
    case unauthorizedError
    
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
        }
    }
}
