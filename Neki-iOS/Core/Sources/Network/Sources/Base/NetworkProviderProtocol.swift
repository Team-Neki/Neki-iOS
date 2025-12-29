//
//  NetworkProviderProtocol.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public protocol NetworkProviderProtocol {
    func request(endpoint: Endpoint) async throws -> Void 
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T
}
