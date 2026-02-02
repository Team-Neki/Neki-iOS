//
//  ProviderType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// OAuth 공급자 종류
public enum ProviderType: String, Sendable {
    case local = "local"
    case apple = "apple"
    case kakao = "kakao"
    case test = "test"
    
    var name: String { self.rawValue }
}
