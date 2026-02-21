//
//  MyPageEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation

enum MyPageEndpoint {
    case fetchAppVersion(platform: String)
}


// MARK: - MyPageEndpoint + Endpoint

extension MyPageEndpoint: Endpoint {
    var authorizationType: AuthorizationType { .none }
    
    var contentType: HTTPContentType { .json }
    
    var path: String {
        switch self {
        case let .fetchAppVersion(platform): return "versions/\(platform)"
        }
    }
    
    var method: HTTPMethodType { .get }
    
    var body: (any Encodable)? { nil }
}
