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
    case boothFavorite(action: MapFilterAction, brandName: String)
    case mapRouteClick(mapType: DirectionAppType)
}


// MARK: - MapAnalyticsEvent + AnalyticsEvent

extension MapAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .mapReSearch: return .mapReSearch
        case .mapBrandFilterToggle: return .mapBrandFilterToggle
        case .boothSelect: return .boothSelect
        case .boothFavorite: return .boothFavorite
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
        case let .boothFavorite(action, brandName):
            return [.action: action.rawValue, .brandName: brandName]
        case let .mapRouteClick(mapType):
            return [.mapType: mapType.rawValue]
        }
    }
}
