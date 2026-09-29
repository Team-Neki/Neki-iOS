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
    case searchRegions(keyword: String, page: Int, size: Int)
    case searchStations(keyword: String, page: Int, size: Int)
    case searchPhotoBooths(keyword: String, page: Int, size: Int)
    /// 고른 지역·역의 부스 목록. 부스 검색과 경로가 같고 메서드로 갈립니다.
    case searchResultPhotoBooths(dto: FetchSearchResultPhotoBoothsDTO.Request)
    /// 고른 지역·역의 목록에서 쓸 수 있는 필터. 부스 목록과 요청 body가 같습니다.
    case searchFilter(dto: FetchSearchFilterDTO.Request)
}


// MARK: - MapEndpoint + Endpoint

extension MapEndpoint: Endpoint {
    var authorizationType: AuthorizationType { .bearer }
    
    var contentType: HTTPContentType {
        switch self {
        case .polygon, .point, .updateFavorite, .fetchFavorites, .fetchBrands, .updateBrandOrder,
             .searchRegions, .searchStations, .searchPhotoBooths, .searchResultPhotoBooths,
             .searchFilter: return .json
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
        case .searchRegions: return "/search/regions"
        case .searchStations: return "/search/stations"
        case .searchPhotoBooths, .searchResultPhotoBooths: return "/search/photo-booths"
        case .searchFilter: return "/search/filter"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .polygon, .point, .searchResultPhotoBooths, .searchFilter: return .post
        case .updateFavorite: return .patch
        case .fetchFavorites, .fetchBrands, .searchRegions, .searchStations, .searchPhotoBooths: return .get
        case .updateBrandOrder: return .put
        }
    }
    
    var queryParameters: [String: String]? {
        switch self {
        case let .searchRegions(keyword, page, size),
             let .searchStations(keyword, page, size),
             let .searchPhotoBooths(keyword, page, size):
            return ["keyword": keyword, "page": String(page), "size": String(size)]
            
        case .polygon, .point, .updateFavorite, .fetchFavorites, .fetchBrands, .updateBrandOrder,
             .searchResultPhotoBooths, .searchFilter:
            return nil
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case let .polygon(dto): return dto
        case let .point(dto): return dto
        case let .updateFavorite(_, dto): return dto
        case .fetchFavorites, .fetchBrands: return nil
        case let .updateBrandOrder(dto): return dto
        case .searchRegions, .searchStations, .searchPhotoBooths: return nil
        case let .searchResultPhotoBooths(dto): return dto
        case let .searchFilter(dto): return dto
        }
    }
}
