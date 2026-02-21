//
//  AgreeTermsDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/8/26.
//

import Foundation

enum AgreeTermsDTO {
    struct Request: Encodable {
        let agreements: [AgreementsDTO]
    }
    
    typealias Response = EmptyData
}

struct AgreementsDTO: Codable {
    let termID: Int
    let agreed: Bool
    
    enum CodingKeys: String, CodingKey {
        case termID = "termId"
        case agreed
    }
}
