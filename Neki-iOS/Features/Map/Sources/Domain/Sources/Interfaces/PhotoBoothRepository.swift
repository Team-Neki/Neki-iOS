//
//  PhotoBoothRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

protocol PhotoBoothRepository {
    /// 특정 지도 영역 내의 포토부스 목록을 가져옵니다.
    /// - Parameter bounds: 조회 시점의 지리적 영역
    /// - Returns: 해당 영역 내의 포토부스 배열
    func readPhotoBooths(in bounds: GeographicBoundingBox) async throws -> [PhotoBooth]
}
