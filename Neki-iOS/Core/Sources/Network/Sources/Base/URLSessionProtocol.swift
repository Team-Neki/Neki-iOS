//
//  URLSessionProtocol.swift
//  Neki-iOS
//
//  Created by OneTen on 12/31/25.
//

import Foundation

public protocol URLSessionProtocol {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
