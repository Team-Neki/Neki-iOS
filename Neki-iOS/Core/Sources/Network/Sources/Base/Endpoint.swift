//
//  Endpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation

public enum HeaderType {
    case noneHeader
    case accessTokenHeader
    case refreshTokenHeader
}

public protocol Endpoint {
    var headerType: HeaderType { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var body: Encodable? { get }
    var query: [URLQueryItem]? { get }
}
