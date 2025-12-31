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
    private let decoder: JSONDecoder
    
    public init(
        session: URLSessionProtocol = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    ///
    /// voidResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 Void 값을 반환합니다.
    public func request(endpoint: Endpoint) async throws {
        let request = try endpoint.asURLRequest()
        
        // 네트워크 검증을 위한 request 로그 출력
        requestLog(request)
        
        // 네트워크 요청
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            responseLog(data: data, response: response)
            
            try validateResponse(response: response)
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
        requestLog(request)
        
        // 네트워크 요청
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            
            responseLog(data: data, response: response)
            
            try validateResponse(response: response)
            
            return try decode(data: data)
        } catch {
            Logger.network.error("❌ Network Error: \(error.localizedDescription)")
            throw error
        }
    }
    
}


// MARK: - validate & decode

private extension DefaultNetworkProvider {
    func validateResponse(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.responseError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.badRequestError
        case 401:
            throw NetworkError.unauthorizedError
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.internalServerError
        default:
            throw NetworkError.unknownError
        }
    }
    
    func decode<T: Decodable>(data: Data) throws -> T {
        do {
            return try self.decoder.decode(T.self, from: data)
        } catch {
            Logger.network.error("❌ Decoding Error: \(error.localizedDescription)")
            throw NetworkError.responseDecodingError
        }
    }
}


// MARK: - Request & Response Log

private extension DefaultNetworkProvider {
    func requestLog(_ request: URLRequest) {
        Logger.network.debug("➡️ [REQUEST] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            Logger.network.debug("🧾 Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Logger.network.debug("📦 Body: \(bodyString)")
        }
    }
    
    func responseLog(data: Data, response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        Logger.network.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.network.debug("📨 Response Body: \(responseBody)")
        }
    }
}
