//
//  MainTabAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by OneTen on 4/19/26.
//

import Foundation

public enum MainTabAnalyticsEvent: AnalyticsEvent {
    case archivingView
    case poseView
    case mapView
    
    public var name: AnalyticsEventName {
        switch self {
        case .archivingView: return .archivingView
        case .poseView: return .poseView
        case .mapView: return .mapView
        }
    }
    
    public var parameters: [AnalyticsParameterKey: Any]? {
        return nil
    }
}
