//
//  TermsType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum TermsType: Int, CaseIterable, Identifiable {
    case serviceUsage = 1, privacyPolicy, locationService
    
    public var id: Int { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .serviceUsage: return "서비스 이용 약관"
        case .privacyPolicy: return "개인정보 수집 및 이용 동의"
        case .locationService: return "위치정보 수집 및 이용 동의"
        }
    }
}

public struct UserAgreement: Identifiable, Equatable {
    public var id: Int { type.id }
    public let type: TermsType
    public let isRequired: Bool
    public var isAgreed: Bool
    public let termInformationURL: URL?
    
    public init(type: TermsType, isRequired: Bool = true, isAgreed: Bool = false, termInformationURL: URL? = nil) {
        self.type = type
        self.isRequired = isRequired
        self.isAgreed = isAgreed
        self.termInformationURL = termInformationURL
    }
}
