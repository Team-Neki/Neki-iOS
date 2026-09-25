//
//  MapAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum MapAnalyticsEvent {
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
    /// 후보 추가 페이지의 정상 응답을 기록합니다. page는 2 이상이며 개수는 해당 페이지 기준입니다.
    /// 동일 페이지 중복 집계 방지는 수집 호출부에서 처리합니다.
    case mapSearchLoadMore(
        query: String,
        page: Int,
        pageResultCount: Int,
        hasNextPage: Bool
    )
    case mapReExplore(hasFilter: Bool, regionChanged: Bool)
    case mapBrandFilterToggle(action: MapFilterAction, selectedCount: Int, brandName: String)
    /// source는 선택 당시 지도에 적용된 결과의 출처입니다.
    /// 수집 경로 연결 전 기존 호출은 source를 생략하여 기존 전송 파라미터를 유지합니다.
    case boothSelect(
        brandName: String,
        entryPoint: MapEntryPoint,
        source: MapBoothSelectionSource? = nil
    )
    case boothFavoriteAdd(boothName: String, brandName: String)
    case boothFavoriteRemove(boothName: String, brandName: String)
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
        case .mapSearchView:
            return nil
        case let .mapSearchResult(query, resultStatus):
            return [.query: .string(query), .resultStatus: .string(resultStatus.rawValue)]
        case let .mapSearchCandidateSelect(query, candidateType, candidateName):
            return [
                .query: .string(query),
                .candidateType: .string(candidateType.rawValue),
                .candidateName: .string(candidateName)
            ]
        case let .mapSearchLoadMore(query, page, pageResultCount, hasNextPage):
            return [
                .query: .string(query),
                .page: .integer(page),
                .pageResultCount: .integer(pageResultCount),
                .hasNextPage: .boolean(hasNextPage)
            ]
        case let .mapReExplore(hasFilter, regionChanged):
            return [.hasFilter: .boolean(hasFilter), .regionChanged: .boolean(regionChanged)]
        case let .mapBrandFilterToggle(action, selectedCount, brandName):
            return [
                .action: .string(action.rawValue),
                .selectedCount: .integer(selectedCount),
                .brandName: .string(brandName)
            ]
        case let .boothSelect(brandName, entryPoint, source):
            var parameters: [AnalyticsParameterKey: AnalyticsParameterValue] = [
                .brandName: .string(brandName),
                .entryPoint: .string(entryPoint.rawValue)
            ]
            if let source { parameters[.source] = .string(source.rawValue) }
            return parameters
        case let .boothFavoriteAdd(boothName, brandName):
            return [.boothName: .string(boothName), .brandName: .string(brandName)]
        case let .boothFavoriteRemove(boothName, brandName):
            return [.boothName: .string(boothName), .brandName: .string(brandName)]
        case let .favoriteBoothFilterOn(favoriteBoothCount):
            return [.favoriteBoothCount: .integer(favoriteBoothCount)]
        case .favoriteBoothFilterOff:
            return nil
        case let .favoriteBoothView(favoriteBoothCount):
            return [.favoriteBoothCount: .integer(favoriteBoothCount)]
        case let .brandOrderSave(orderedBrands):
            let priorityBrandNames = orderedBrands.map(\.name)
            return [
                .priorityBrand1: .string(priorityBrandNames.indices.contains(0) ? priorityBrandNames[0] : ""),
                .priorityBrand2: .string(priorityBrandNames.indices.contains(1) ? priorityBrandNames[1] : ""),
                .priorityBrand3: .string(priorityBrandNames.indices.contains(2) ? priorityBrandNames[2] : "")
            ]
        case let .mapRouteClick(mapType):
            return [.mapType: .string(mapType.rawValue)]
        }
    }
}
