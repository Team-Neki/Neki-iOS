//
//  DefaultNetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import os

public final class DefaultNetworkProvider: NetworkProvider {
    
    private let session: URLSessionProtocol
    
    public init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    ///
    /// voidResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 Void 값을 반환합니다.
    public func request(endpoint: Endpoint) async throws -> Void {
        let request = try endpoint.asURLRequest()
        
        // 네트워크 검증을 위한 request 로그 출력
        logRequest(request)
        
        // 네트워크 요청
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            try voidResponse(data: data, response: response)
        } catch {
            Logger.network.error("❌ Network Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 네트워크 요청을 수행하고 제네릭 타입으로 응답 데이터를 디코딩합니다.
    ///
    /// decodableResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 `JSONDecoder`를 통해 `T` 타입으로 디코딩하여 반환합니다.
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        let request = try endpoint.asURLRequest()
        
        // 네트워크 검증을 위한 request 로그 출력
        logRequest(request)
        
        // 네트워크 요청
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            return try decodableResponse(data: data, response: response)
        } catch {
            Logger.network.error("❌ Network Error: \(error.localizedDescription)")
            throw error
        }
    }
    
}

private extension DefaultNetworkProvider {
    func logRequest(_ request: URLRequest) {
        Logger.network.debug("➡️ [REQUEST] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            Logger.network.debug("🧾 Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Logger.network.debug("📦 Body: \(bodyString)")
        }
    }
    
    func voidResponse(data: Data, response: URLResponse) throws {
        // response 검증 및 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("❌ Invalid HTTPURLResponse")
            throw NetworkError.responseError
        }
        
        // response Statue Code 확인
        Logger.network.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        // responseBody 확인
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.network.debug("📨 Response Body: \(responseBody)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.badRequestError
        case 401:
            throw NetworkError.unauthorizedError
        case 500...599:
            throw NetworkError.internalServerError
        default:
            throw NetworkError.unknownError
        }
    }
    
    func decodableResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        // response 검증 및 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("❌ Invalid HTTPURLResponse")
            throw NetworkError.responseError
        }
        
        // response Statue Code 확인
        Logger.network.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        // responseBody 확인
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.network.debug("📨 Response Body: \(responseBody)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                return decodedResponse
            } catch {
                Logger.network.error("❌ Decoding Error: \(error.localizedDescription)")
                if let raw = String(data: data, encoding: .utf8) {
                    Logger.network.error("📨 Raw Response Data: \(raw)")
                }
                throw NetworkError.responseDecodingError
            }
        case 400:
            throw NetworkError.badRequestError
        case 401:
            throw NetworkError.unauthorizedError
        case 500...599:
            throw NetworkError.internalServerError
        default:
            throw NetworkError.unknownError
        }
    }
}
