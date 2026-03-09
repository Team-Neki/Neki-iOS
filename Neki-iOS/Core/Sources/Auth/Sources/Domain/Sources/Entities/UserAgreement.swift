//
//  UserAgreement.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public struct Term: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let isRequired: Bool
    public let termInformationURL: URL?
    
    public init(id: Int, title: String, isRequired: Bool = true, termInformationURL: URL? = nil) {
        self.id = id
        self.title = title
        self.isRequired = isRequired
        self.termInformationURL = termInformationURL
    }
}

public struct UserAgreement: Identifiable, Equatable, Sendable {
    public var id: Int { term.id }
    public let term: Term
    public var isAgreed: Bool
    
    public init(term: Term, isAgreed: Bool = false) {
        self.term = term
        self.isAgreed = isAgreed
    }
}
