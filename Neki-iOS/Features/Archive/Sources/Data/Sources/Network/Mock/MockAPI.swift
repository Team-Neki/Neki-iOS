//
//  MockAPI.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

enum MockAPI {
    case getTest(page: Int, category: String)
    case postTest(title: String, content: String)
}

extension MockAPI: Endpoint {
    var headerType: HeaderType {
        switch self {
        case .getTest:
            return .accessTokenHeader
        case .postTest:
            return .noneHeader
        }
    }
    
    var path: String {
        switch self {
        case .getTest:
            return "mock/get-test"
        case .postTest:
            return "mock/post-test"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .getTest:
            return .get
        case .postTest:
            return .post
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case .getTest:
            return nil
        case .postTest(let title, let content):
            return MockRequestDTO(title: title, content: content)
        }
    }
    
    var query: [URLQueryItem]? {
        switch self {
        case .getTest(let page, let category):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "category", value: category)
            ]
        case .postTest:
            return nil
        }
    }
}
