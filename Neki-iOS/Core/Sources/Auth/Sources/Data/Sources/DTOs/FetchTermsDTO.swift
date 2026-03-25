//
//  FetchTermsDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/9/26.
//

import Foundation

enum FetchTermsDTO {
    struct Response: Decodable {
        let terms: [TermDTO]
    }
}

struct TermDTO: Decodable {
    let id: Int
    let termType: String?
    let title: String
    let termInformationURL: URL?
    let isRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, termType, title, isRequired
        case termInformationURL = "url"
    }
    
    func toEntity() -> Term { Term(id: id, title: title, isRequired: isRequired, termInformationURL: termInformationURL) }
}
