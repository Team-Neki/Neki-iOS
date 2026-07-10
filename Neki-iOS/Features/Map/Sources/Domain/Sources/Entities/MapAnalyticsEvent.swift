//
//  MapAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum MapAnalyticsEvent {
    case mapReSearch(hasFilter: Bool, regionChanged: Bool)
    case mapBrandFilterToggle(action: MapFilterAction, selectedCount: Int, brandName: String)
    case boothSelect(brandName: String, entryPoint: MapEntryPoint)
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
        case .mapReSearch: return .mapReSearch
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
    
    var parameters: [AnalyticsParameterKey : Any]? {
        switch self {
        case let .mapReSearch(hasFilter, regionChanged):
            return [.hasFilter: hasFilter, .regionChanged: regionChanged]
        case let .mapBrandFilterToggle(action, selectedCount, brandName):
            return [.action: action.rawValue, .selectedCount: selectedCount, .brandName: brandName]
        case let .boothSelect(brandName, entryPoint):
            return [.brandName: brandName, .entryPoint: entryPoint.rawValue]
        case let .boothFavoriteAdd(boothName, brandName):
            return [.boothName: boothName, .brandName: brandName]
        case let .boothFavoriteRemove(boothName, brandName):
            return [.boothName: boothName, .brandName: brandName]
        case let .favoriteBoothFilterOn(favoriteBoothCount):
            return [.favoriteBoothCount: favoriteBoothCount]
        case .favoriteBoothFilterOff:
            return nil
        case let .favoriteBoothView(favoriteBoothCount):
            return [.favoriteBoothCount: favoriteBoothCount]
        case let .brandOrderSave(orderedBrands):
            let priorityBrandNames = orderedBrands.map(\.name)
            return [
                .priorityBrand1: priorityBrandNames.indices.contains(0) ? priorityBrandNames[0] : "",
                .priorityBrand2: priorityBrandNames.indices.contains(1) ? priorityBrandNames[1] : "",
                .priorityBrand3: priorityBrandNames.indices.contains(2) ? priorityBrandNames[2] : ""
            ]
        case let .mapRouteClick(mapType):
            return [.mapType: mapType.rawValue]
        }
    }
}
