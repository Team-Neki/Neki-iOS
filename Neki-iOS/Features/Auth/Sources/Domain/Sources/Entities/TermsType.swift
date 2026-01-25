//
//  TermsType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum TermsType: CaseIterable, Identifiable {
    case serviceUsage, privacyPolicy, locationService
    
    public var id: Int { self.hashValue }
    
    public var displayName: String {
        switch self {
        case .serviceUsage: return "서비스 이용 약관"
        case .privacyPolicy: return "개인정보 수집 및 이용 동의"
        case .locationService: return "위치정보 수집 및 이용 동의"
        }
    }
}

public struct UserAgreement: Identifiable, Equatable {
    public var id: TermsType { type }
    public let type: TermsType
    public let isRequired: Bool
    public var isAgreed: Bool
    
    public init(type: TermsType, isRequired: Bool = true, isAgreed: Bool = false) {
        self.type = type
        self.isRequired = isRequired
        self.isAgreed = isAgreed
    }
}
