//
//  MapBoothSelectionSource.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/25/26.
//

import Foundation

/// 포토부스 선택 당시 지도 결과의 출처입니다. 선택 UI를 나타내는 MapEntryPoint와 구분합니다.
enum MapBoothSelectionSource: String, Sendable {
    case search = "search"
    case map = "map"
}
