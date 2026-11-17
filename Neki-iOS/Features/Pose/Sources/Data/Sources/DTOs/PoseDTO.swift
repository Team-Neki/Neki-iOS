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
    let width: Int?
    let height: Int?
    /// 2인 포즈의 관계(`FRIEND`·`COUPLE`·`SSUM`)입니다. 관계가 없는 포즈는 null입니다.
    let relationValue: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "poseId"
        case peopleCountValue = "headCount"
        case imageURLString = "imageUrl"
        case isScrapped = "scrap"
        case contentType
        case width
        case height
        case relationValue = "relation"
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
        // 모르는 관계 값은 관계 없는 포즈로 둡니다. 목록 전체를 실패로 만들지 않습니다.
        let relation: PoseRelation? = switch relationValue {
        case "FRIEND": .friend
        case "COUPLE": .couple
        case "SSUM": .crush
        default: nil
        }
        
        return Pose(
            id: id,
            peopleCountOption: peopleCountOption,
            imageURL: imageURL,
            isScrapped: isScrapped ?? false,
            contentType: imageContentType,
            width: width,
            height: height,
            relation: relation
        )
    }
}
