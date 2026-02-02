//
//  PoseDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

struct PoseDTO: Decodable {
    let id: Int
    let peopleCountValue: String
    let imageURLString: String
    let isScrapped: Bool?
    let contentType: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "poseId"
        case peopleCountValue = "headCount"
        case imageURLString = "imageUrl"
        case isScrapped = "scrap"
        case contentType
        case createdAt
    }
    
    func toEntity() -> Pose {
        let peopleCountOption: PeopleCountOption
        switch peopleCountValue {
        case "ONE": peopleCountOption = .solo
        case "TWO": peopleCountOption = .duo
        case "THREE": peopleCountOption = .trio
        case "FOUR": peopleCountOption = .quartet
        case "FIVE_OR_MORE": peopleCountOption = .overQuartet
        default: peopleCountOption = .solo
        }
        
        let imageURL = URL(string: imageURLString)
        let imageContentType = ImageContentType(contentType) ?? .jpeg
        
        return Pose(id: id, peopleCountOption: peopleCountOption, imageURL: imageURL, isScrapped: isScrapped ?? false, contentType: imageContentType, createdAt: createdAt)
    }
}
