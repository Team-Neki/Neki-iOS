//
//  TokenPair.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
}
