//
//  AnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public protocol AnalyticsEvent: Sendable {
    var name: AnalyticsEventName { get }
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? { get }
}
