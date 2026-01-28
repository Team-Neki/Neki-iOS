//
//  ProviderType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// OAuth 공급자 종류
public enum ProviderType: String, Sendable {
    case local = "LOCAL"
    case apple = "APPLE"
    case kakao = "KAKAO"
    case test = "TEST"
    
    var name: String { self.rawValue }
}
