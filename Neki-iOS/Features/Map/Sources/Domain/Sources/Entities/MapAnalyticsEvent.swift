//
//  MapAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum MapAnalyticsEvent {
    /// 지도 첫 화면이 보일 때마다 기록합니다. 탭을 옮겨 오거나 브랜드 순서 화면, QR·알림 목록에서 돌아올 때도 포함합니다.
    case mapView
    /// 검색창을 통해 검색 모드에 정상 진입했을 때 기록합니다. 모드 내 재포커스는 제외합니다.
    case mapSearchView
    /// 검색 후보 첫 페이지의 정상 응답만 기록합니다. query는 입력 원문이며 기술적 실패와 POI 조회는 제외합니다.
    case mapSearchResult(query: String, resultStatus: MapSearchResultStatus)
    /// 사용자가 직접 선택한 후보를 기록합니다. query는 해당 후보 목록 조회에 사용한 원문입니다.
    case mapSearchCandidateSelect(
        query: String,
        candidateType: MapSearchCandidateType,
        candidateName: String
    )
    /// 후보 유형별 추가 페이지의 정상 응답을 기록합니다. 최초 페이지와 요청 실패는 제외합니다.
    ///
    /// - Parameters:
    ///   - query: 추가 조회에 사용한 검색어 원문입니다.
    ///   - candidateType: 추가 조회한 후보 유형입니다.
    ///   - page: 해당 후보 유형의 페이지 번호이며 2부터 기록합니다.
    ///   - pageResultCount: 해당 후보 유형의 해당 페이지에서 반환된 결과 수입니다.
    ///   - hasNextPage: 해당 후보 유형의 다음 페이지 존재 여부입니다.
    /// - Note: 수집 호출부에서 동일 검색의 후보 유형·페이지별 중복 집계를 방지합니다.
    ///   검색어와 페이지 번호가 같아도 후보 유형이 다르면 별도로 기록합니다.
    case mapSearchLoadMore(
        query: String,
        candidateType: MapSearchCandidateType,
        page: Int,
        pageResultCount: Int,
        hasNextPage: Bool
    )
    case mapReExplore(hasFilter: Bool, regionChanged: Bool)
    case mapBrandFilterToggle(action: MapFilterAction, selectedCount: Int, brandName: String, brandID: PhotoBoothBrand.ID)
    /// source는 선택 당시 지도에 적용된 결과의 출처입니다.
    case boothSelect(
        brandName: String,
        brandID: PhotoBoothBrand.ID,
        entryPoint: MapEntryPoint,
        source: MapBoothSelectionSource
    )
    case boothFavoriteAdd(boothName: String, brandName: String, brandID: PhotoBoothBrand.ID)
    case boothFavoriteRemove(boothName: String, brandName: String, brandID: PhotoBoothBrand.ID)
    case favoriteBoothFilterOn(favoriteBoothCount: Int)
    case favoriteBoothFilterOff
    case favoriteBoothView(favoriteBoothCount: Int)
    case brandOrderSave(orderedBrands: [PhotoBoothBrand])
    case mapRouteClick(mapType: DirectionAppType)
}


// MARK: - MapAnalyticsEvent + AnalyticsEvent

extension MapAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .mapView: return .mapView
        case .mapSearchView: return .mapSearchView
        case .mapSearchResult: return .mapSearchResult
        case .mapSearchCandidateSelect: return .mapSearchCandidateSelect
        case .mapSearchLoadMore: return .mapSearchLoadMore
        case .mapReExplore: return .mapReSearch
        case .mapBrandFilterToggle: return .mapBrandFilterToggle
        case .boothSelect: return .boothSelect
        case .boothFavoriteAdd: return .boothFavoriteAdd
        case .boothFavoriteRemove: return .boothFavoriteRemove
        case .favoriteBoothFilterOn: return .favoriteBoothFilterOn
        case .favoriteBoothFilterOff: return .favoriteBoothFilterOff
        case .favoriteBoothView: return .favoriteBoothView
        case .brandOrderSave: return .brandOrderSave
        case .mapRouteClick: return .mapRouteClick
        }
    }
    
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case .mapView, .mapSearchView:
            return nil
        case let .mapSearchResult(query, resultStatus):
            return [.query: .string(query), .resultStatus: .string(resultStatus.rawValue)]
        case let .mapSearchCandidateSelect(query, candidateType, candidateName):
            return [
                .query: .string(query),
                .candidateType: .string(candidateType.rawValue),
                .candidateName: .string(candidateName)
            ]
        case let .mapSearchLoadMore(query, candidateType, page, pageResultCount, hasNextPage):
            return [
                .query: .string(query),
                .candidateType: .string(candidateType.rawValue),
                .page: .integer(page),
                .pageResultCount: .integer(pageResultCount),
                .hasNextPage: .boolean(hasNextPage)
            ]
        case let .mapReExplore(hasFilter, regionChanged):
            return [.hasFilter: .boolean(hasFilter), .regionChanged: .boolean(regionChanged)]
        case let .mapBrandFilterToggle(action, selectedCount, brandName, brandID):
            return [
                .action: .string(action.rawValue),
                .selectedCount: .integer(selectedCount),
                .brandName: .string(brandName),
                .brandId: .string(String(brandID))
            ]
        case let .boothSelect(brandName, brandID, entryPoint, source):
            return [
                .brandName: .string(brandName),
                .brandId: .string(String(brandID)),
                .entryPoint: .string(entryPoint.rawValue),
                .source: .string(source.rawValue)
            ]
        case let .boothFavoriteAdd(boothName, brandName, brandID):
            return [.boothName: .string(boothName), .brandName: .string(brandName), .brandId: .string(String(brandID))]
        case let .boothFavoriteRemove(boothName, brandName, brandID):
            return [.boothName: .string(boothName), .brandName: .string(brandName), .brandId: .string(String(brandID))]
        case let .favoriteBoothFilterOn(favoriteBoothCount):
            return [.favoriteBoothCount: .integer(favoriteBoothCount)]
        case .favoriteBoothFilterOff:
            return nil
        case let .favoriteBoothView(favoriteBoothCount):
            return [.favoriteBoothCount: .integer(favoriteBoothCount)]
        case let .brandOrderSave(orderedBrands):
            let priorityBrandNames = orderedBrands.map(\.name)
            let priorityBrandIDs = orderedBrands.map { String($0.id) }
            return [
                .priorityBrand1: .string(priorityBrandNames.indices.contains(0) ? priorityBrandNames[0] : ""),
                .priorityBrand2: .string(priorityBrandNames.indices.contains(1) ? priorityBrandNames[1] : ""),
                .priorityBrand3: .string(priorityBrandNames.indices.contains(2) ? priorityBrandNames[2] : ""),
                .priorityBrandId1: .string(priorityBrandIDs.indices.contains(0) ? priorityBrandIDs[0] : ""),
                .priorityBrandId2: .string(priorityBrandIDs.indices.contains(1) ? priorityBrandIDs[1] : ""),
                .priorityBrandId3: .string(priorityBrandIDs.indices.contains(2) ? priorityBrandIDs[2] : "")
            ]
        case let .mapRouteClick(mapType):
            return [.mapType: .string(mapType.rawValue)]
        }
    }
}


// MARK: - MapAnalyticsEvent + Equatable

extension MapAnalyticsEvent: Equatable {}
