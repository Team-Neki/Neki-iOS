//
//  MapEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

enum MapEndpoint {
    case polygon(dto: FetchPhotoBoothsDTO.Request)
    case point(dto: FetchNearbyPhotoBoothsDTO.Request)
    case detail(id: Int)
    case updateFavorite(id: Int, dto: TogglePhotoBoothFavoriteDTO)
    case fetchBrands
}


// MARK: - MapEndpoint + Endpoint

extension MapEndpoint: Endpoint {
    var authorizationType: AuthorizationType { .bearer }
    
    var contentType: HTTPContentType {
        switch self {
        case .polygon, .point, .detail, .updateFavorite, .fetchBrands: return .json
        }
    }
    
    var path: String {
        switch self {
        case .polygon: return "/photo-booths/polygon"
        case .point: return "/photo-booths/point"
        // TODO: 서버 상세 API 계약 확정 시 path를 검증합니다.
        case let .detail(id): return "/photo-booths/\(id)"
        // TODO: 서버 즐겨찾기 API 계약 확정 시 method/path/body를 검증합니다.
        case let .updateFavorite(id, _): return "/photo-booths/\(id)/favorite"
        case .fetchBrands: return "/photo-booths/brand"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .polygon, .point: return .post
        case .detail: return .get
        case .updateFavorite: return .patch
        case .fetchBrands: return .get
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case let .polygon(dto): return dto
        case let .point(dto): return dto
        case .detail: return nil
        case let .updateFavorite(_, dto): return dto
        case .fetchBrands: return nil
        }
    }
}
