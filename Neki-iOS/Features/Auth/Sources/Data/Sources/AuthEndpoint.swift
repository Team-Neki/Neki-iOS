//
//  AuthEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

enum AuthEndpoint {
    case reissueToken
    case login(idToken: String)
}


// MARK: - AuthEndpoint + Endpoint
// TODO: API 명세서 확인하여 구현
//extension AuthEndpoint: Endpoint {
//    
//}
