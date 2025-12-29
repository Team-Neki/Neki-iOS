//
//  HTTPMethodType.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation

public enum HTTPMethodType {
    case get
    case post
    case delete
    case put
    case patch
    
    var key: String {
        switch self {
        case .get:
            "GET"
        case .post:
            "POST"
        case .delete:
            "DELETE"
        case .put:
            "PUT"
        case .patch:
            "PATCH"
        }
    }
}
