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
    case updateFavorite(id: Int, dto: TogglePhotoBoothFavoriteDTO)
    case fetchFavorites
    case fetchBrands
    case updateBrandOrder(dto: UpdatePhotoBoothBrandOrderDTO.Request)
}


// MARK: - MapEndpoint + Endpoint

extension MapEndpoint: Endpoint {
    var authorizationType: AuthorizationType { .bearer }
    
    var contentType: HTTPContentType {
        switch self {
        case .polygon, .point, .updateFavorite, .fetchFavorites, .fetchBrands, .updateBrandOrder: return .json
        }
    }
    
    var path: String {
        switch self {
        case .polygon: return "/photo-booths/polygon"
        case .point: return "/photo-booths/point"
        case let .updateFavorite(id, _): return "/photo-booths/\(id)/favorite"
        case .fetchFavorites: return "/photo-booths/favorite"
        case .fetchBrands: return "/photo-booths/brand"
        case .updateBrandOrder: return "/photo-booths/brand/order"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .polygon, .point: return .post
        case .updateFavorite: return .patch
        case .fetchFavorites, .fetchBrands: return .get
        case .updateBrandOrder: return .put
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case let .polygon(dto): return dto
        case let .point(dto): return dto
        case let .updateFavorite(_, dto): return dto
        case .fetchFavorites, .fetchBrands: return nil
        case let .updateBrandOrder(dto): return dto
        }
    }
}
