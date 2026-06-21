//
//  FetchFavoritePhotoBoothsDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/21/26.
//

import Foundation

enum FetchFavoritePhotoBoothsDTO {
    struct Response: Decodable {
        let items: [PhotoBoothDTO]
    }
}
