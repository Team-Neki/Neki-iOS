//
//  MapAnalyticsEventTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import Testing
@testable import Neki_iOS

@MainActor
struct MapAnalyticsEventTests {
    @Test("브랜드를 다루는 이벤트는 브랜드 이름과 함께 브랜드 ID를 문자열로 `brand_id`에 담는다")
    func brandEvents_sendBrandIDAsString() {
        let events: [MapAnalyticsEvent] = [
            .mapBrandFilterToggle(action: .select, selectedCount: 1, brandName: "포토이즘", brandID: 12),
            .boothSelect(brandName: "포토이즘", brandID: 12, entryPoint: .map, source: .map),
            .boothFavoriteAdd(boothName: "강남점", brandName: "포토이즘", brandID: 12),
            .boothFavoriteRemove(boothName: "강남점", brandName: "포토이즘", brandID: 12)
        ]

        #expect(AnalyticsParameterKey.brandId.name == "brand_id")
        for event in events {
            #expect(stringValue(event.parameters?[.brandId]) == "12")
            #expect(stringValue(event.parameters?[.brandName]) == "포토이즘")
        }
    }

    @Test("브랜드 순서를 저장하면 1~3순위 브랜드 ID를 문자열로 담고, 비어 있는 순위에는 빈 문자열을 담는다")
    func brandOrderSave_sendsPriorityBrandIDs() {
        let orderedBrands = [
            PhotoBoothBrand(id: 3, name: "하루필름", englishName: "HARUFILM", imageURL: nil),
            PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil)
        ]

        let parameters = MapAnalyticsEvent.brandOrderSave(orderedBrands: orderedBrands).parameters

        #expect(AnalyticsParameterKey.priorityBrandId1.name == "priority_brand_id_1")
        #expect(stringValue(parameters?[.priorityBrandId1]) == "3")
        #expect(stringValue(parameters?[.priorityBrandId2]) == "1")
        #expect(stringValue(parameters?[.priorityBrandId3]) == "")
        #expect(stringValue(parameters?[.priorityBrand1]) == "하루필름")
        #expect(stringValue(parameters?[.priorityBrand3]) == "")
    }
}


// MARK: - Helpers

private extension MapAnalyticsEventTests {
    func stringValue(_ value: AnalyticsParameterValue?) -> String? {
        guard case let .string(string) = value else { return nil }
        return string
    }
}
