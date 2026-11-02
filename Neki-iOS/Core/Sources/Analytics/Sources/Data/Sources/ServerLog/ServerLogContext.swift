//
//  ServerLogContext.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import UIKit

/// 서버 로그의 `appVersion`과 `context`에 넣는 기기·앱 정보
/// - Note: Amplitude가 이벤트마다 붙이는 값과 같은 출처, 같은 키를 씁니다(Amplitude-Swift `ContextPlugin`). Amplitude처럼 앱을 실행한 뒤 한 번만 계산합니다.
struct ServerLogContext: Equatable, Sendable {
    let appVersion: String
    let values: [String: String]
}

extension ServerLogContext {
    @MainActor
    static func current(bundle: Bundle = .main) -> ServerLogContext {
        let device = UIDevice.current
        return ServerLogContext(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            machine: hardwareMachine(),
            preferredLanguage: Locale.preferredLanguages.first,
            regionCode: Locale.current.region?.identifier
        )
    }

    init(
        appVersion: String,
        systemName: String,
        systemVersion: String,
        machine: String?,
        preferredLanguage: String?,
        regionCode: String?
    ) {
        var values = [
            "platform": "iOS",
            "os_name": systemName.lowercased(),
            "os_version": systemVersion,
            "device_manufacturer": "Apple",
            "device_model": Self.deviceModel(machine: machine ?? "unknown")
        ]
        values["language"] = preferredLanguage
        values["country"] = regionCode
        self.init(appVersion: appVersion, values: values)
    }

    /// Amplitude와 같이 `hw.machine` 값을 그대로 쓰고, 일부 기기만 이름으로 바꿉니다.
    static func deviceModel(machine: String) -> String {
        if machine == "i386" || machine == "x86_64" { return "Simulator" }
        if machine.hasPrefix("MacBookAir") { return "MacBook Air" }
        if machine.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if machine.hasPrefix("MacBook") { return "MacBook" }
        if machine.hasPrefix("MacPro") { return "Mac Pro" }
        if machine.hasPrefix("Macmini") { return "Mac Mini" }
        if machine.hasPrefix("iMac") { return "iMac" }
        if machine.hasPrefix("Xserve") { return "Xserve" }
        return machine
    }

    private static func hardwareMachine() -> String? {
        var name: [Int32] = [CTL_HW, HW_MACHINE]
        var size = 0
        guard sysctl(&name, 2, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size + 1)
        guard sysctl(&name, 2, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
