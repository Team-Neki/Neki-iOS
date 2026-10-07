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
    /// 지역 자동완성. 지역은 거리를 내려주지 않아 기준 위치를 받지 않습니다.
    case searchCompletionRegions(keyword: String, page: Int, size: Int)
    /// 지하철역 자동완성. 기준 위치를 담으면 서버가 거리를 계산하고 가까운 순으로 내려줍니다.
    case searchCompletionStations(keyword: String, page: Int, size: Int, origin: GeographicCoordinate?)
    /// 포토부스 자동완성. 기준 위치를 담으면 서버가 거리를 계산하고, 일치도가 같은 후보 사이에서 가까운 순으로 내려줍니다.
    case searchCompletionPhotoBooths(keyword: String, page: Int, size: Int, origin: GeographicCoordinate?)
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
             .searchRegions, .searchStations, .searchPhotoBooths,
             .searchCompletionRegions, .searchCompletionStations, .searchCompletionPhotoBooths,
             .searchResultPhotoBooths, .searchFilter: return .json
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
        case .searchCompletionRegions: return "/search/completion/regions"
        case .searchCompletionStations: return "/search/completion/stations"
        case .searchCompletionPhotoBooths: return "/search/completion/photo-booths"
        case .searchPhotoBooths, .searchResultPhotoBooths: return "/search/photo-booths"
        case .searchFilter: return "/search/filter"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .polygon, .point, .searchResultPhotoBooths, .searchFilter: return .post
        case .updateFavorite: return .patch
        case .fetchFavorites, .fetchBrands, .searchRegions, .searchStations, .searchPhotoBooths,
             .searchCompletionRegions, .searchCompletionStations, .searchCompletionPhotoBooths: return .get
        case .updateBrandOrder: return .put
        }
    }
    
    var queryParameters: [String: String]? {
        switch self {
        case let .searchRegions(keyword, page, size),
             let .searchStations(keyword, page, size),
             let .searchPhotoBooths(keyword, page, size),
             let .searchCompletionRegions(keyword, page, size):
            return ["keyword": keyword, "page": String(page), "size": String(size)]
            
        case let .searchCompletionStations(keyword, page, size, origin),
             let .searchCompletionPhotoBooths(keyword, page, size, origin):
            var parameters = ["keyword": keyword, "page": String(page), "size": String(size)]
            // 위도와 경도 중 하나만 보내면 `D-01`이므로 좌표 하나로 받아 늘 함께 담거나 함께 뺍니다.
            if let origin {
                parameters["latitude"] = String(origin.latitude)
                parameters["longitude"] = String(origin.longitude)
            }
            return parameters
            
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
        case .searchRegions, .searchStations, .searchPhotoBooths,
             .searchCompletionRegions, .searchCompletionStations, .searchCompletionPhotoBooths: return nil
        case let .searchResultPhotoBooths(dto): return dto
        case let .searchFilter(dto): return dto
        }
    }
}
