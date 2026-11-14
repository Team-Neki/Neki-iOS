//
//  PoseListDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

enum PoseListDTO {
    struct Response: Decodable {
        let items: [PoseDTO]
        let hasNext: Bool
        /// 조건에 맞는 전체 포즈 수입니다. 표시에만 쓰므로 응답에 없어도 목록은 그대로 받습니다.
        let totalCount: Int?
    }
}
