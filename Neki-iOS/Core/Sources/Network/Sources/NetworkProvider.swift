//
//  NetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import os

public final class NetworkProvider: NetworkProviderProtocol {
    public static let shared = NetworkProvider()
    
    private init() {}
    
    private static var logger: Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "Neki", category: "NetworkProvider")
    }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    ///
    /// voidResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 Void 값을 반환합니다.
    public func request(endpoint: Endpoint) async throws -> Void {
        guard let url = makeURL(endpoint: endpoint) else {
            throw NetworkError.invalidURLError
        }

        let request = try makeURLRequest(url: url, endpoint: endpoint)
        
        
        // 네트워크 검증을 위한 request 로그 출력
        Self.logger.debug("➡️ [REQUEST] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            Self.logger.debug("🧾 Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Self.logger.debug("📦 Body: \(bodyString)")
        }
        
        
        // 네트워크 요청
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try voidResponse(data: data, response: response)
            return ()
        } catch {
            Self.logger.error("❌ Network Error: \(error.localizedDescription)")
            throw NetworkError.networkFail
        }
    }
    
    /// 네트워크 요청을 수행하고 제네릭 타입으로 응답 데이터를 디코딩합니다.
    ///
    /// decodableResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 `JSONDecoder`를 통해 `T` 타입으로 디코딩하여 반환합니다.
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        guard let url = makeURL(endpoint: endpoint) else {
            throw NetworkError.invalidURLError
        }

        let request = try makeURLRequest(url: url, endpoint: endpoint)
        
        
        // 네트워크 검증을 위한 request 로그 출력
        Self.logger.debug("➡️ [REQUEST] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            Self.logger.debug("🧾 Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Self.logger.debug("📦 Body: \(bodyString)")
        }
        
        
        // 네트워크 요청
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try decodableResponse(data: data, response: response)
        } catch {
            Self.logger.error("❌ Network Error: \(error.localizedDescription)")
            throw NetworkError.networkFail
        }
    }

}

private extension NetworkProvider {
    func makeURL(endpoint: Endpoint) -> URL? {
        // BASE URL 불러오기
        guard let baseURL = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            fatalError("🚨Base URL을 찾을 수 없습니다🚨")
        }
        
        // URLComponents를 이용한 초기 URL 생성
        guard let url = URL(string: baseURL)?.appending(path: endpoint.path),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
                
        // 쿼리 아이템이 있으면 추가
        if let queryItems = endpoint.query {
            components.queryItems = queryItems
        }
        
        // 쿼리아이템이 추가된 최종 URL 반환
        return components.url
    }
    
    func makeHeaders(endpoint: Endpoint) -> [String: String] {
        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]
        
        switch endpoint.headerType {
        case .noneHeader:
            break
        case .accessTokenHeader:
            // TODO: - 여기에 토큰 가져오는 로직 추가 (토큰매니저나 키체인매니저 등)
            break
        case .refreshTokenHeader:
            // TODO: - 리프레시 토큰 로직 추가
            break
        }
        
        return headers
    }
    
    func makeURLRequest(url: URL, endpoint: Endpoint) throws -> URLRequest {
        // Request 생성
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // 헤더 설정
        let allHeaders = makeHeaders(endpoint: endpoint)
        request.allHTTPHeaderFields = allHeaders
        
        // Body 인코딩
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.requestEncodingError
            }
        }
        
        // 최종 request 반환
        return request
    }
    
    func voidResponse(data: Data, response: URLResponse) throws {
        // response 검증 및 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("❌ Invalid HTTPURLResponse")
            throw NetworkError.responseError
        }
        
        // response Statue Code 확인
        Self.logger.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        // responseBody 확인
        if let responseBody = String(data: data, encoding: .utf8) {
            Self.logger.debug("📨 Response Body: \(responseBody)")
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
            Self.logger.error("❌ Invalid HTTPURLResponse")
            throw NetworkError.responseError
        }
        
        // response Statue Code 확인
        Self.logger.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        // responseBody 확인
        if let responseBody = String(data: data, encoding: .utf8) {
            Self.logger.debug("📨 Response Body: \(responseBody)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                return decodedResponse
            } catch {
                Self.logger.error("❌ Decoding Error: \(error.localizedDescription)")
                if let raw = String(data: data, encoding: .utf8) {
                    Self.logger.error("📨 Raw Response Data: \(raw)")
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
