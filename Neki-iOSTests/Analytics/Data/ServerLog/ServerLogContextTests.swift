//
//  ServerLogContextTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
import UIKit
@testable import Neki_iOS

struct ServerLogContextTests {
    @Test("Amplitude와 같은 기기 정보를 camelCase 키로 담는다")
    func init_usesAmplitudeValuesWithCamelCaseKeys() {
        let context = ServerLogContext(
            appVersion: "1.2.9",
            systemName: "iOS",
            systemVersion: "26.0",
            machine: "iPhone17,1",
            preferredLanguage: "ko-KR",
            regionCode: "KR"
        )

        #expect(context.appVersion == "1.2.9")
        #expect(context.values == [
            "platform": "iOS",
            "osName": "ios",
            "osVersion": "26.0",
            "deviceManufacturer": "Apple",
            "deviceModel": "iPhone17,1",
            "language": "ko-KR",
            "country": "KR"
        ])
    }

    @Test("언어·지역을 알 수 없으면 그 키를 넣지 않는다")
    func init_withoutLanguageAndRegion_omitsKeys() {
        let context = ServerLogContext(
            appVersion: "1.2.9",
            systemName: "iOS",
            systemVersion: "26.0",
            machine: nil,
            preferredLanguage: nil,
            regionCode: nil
        )

        #expect(context.values["language"] == nil)
        #expect(context.values["country"] == nil)
        #expect(context.values["deviceModel"] == "unknown")
    }

    @Test(
        "기기 모델은 hw.machine 값을 쓰고 Amplitude가 바꾸는 값만 이름으로 바꾼다",
        arguments: zip(
            ["iPhone17,1", "x86_64", "i386", "arm64", "MacBookPro18,3", "iMac21,1"],
            ["iPhone17,1", "Simulator", "Simulator", "arm64", "MacBook Pro", "iMac"]
        )
    )
    func deviceModel_followsAmplitudeMapping(machine: String, expected: String) {
        #expect(ServerLogContext.deviceModel(machine: machine) == expected)
    }

    @MainActor
    @Test("실행 중인 기기의 정보로 문맥을 만든다")
    func current_readsRunningDevice() async {
        let context = ServerLogContext.current(system: await UIKitDeviceSystem().read())

        #expect(context.appVersion == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(context.values["platform"] == "iOS")
        #expect(context.values["osName"] == "ios")
        #expect(context.values["osVersion"] == UIDevice.current.systemVersion)
        #expect(context.values["deviceManufacturer"] == "Apple")
        #expect(context.values["deviceModel"]?.isEmpty == false)
    }
}
