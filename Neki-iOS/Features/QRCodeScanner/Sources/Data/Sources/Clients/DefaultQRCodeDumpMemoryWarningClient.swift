//
//  DefaultQRCodeDumpMemoryWarningClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import Dependencies
import Foundation
import UIKit

extension QRCodeDumpMemoryWarningClient: DependencyKey {
    static let liveValue = QRCodeDumpMemoryWarningClient(events: {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
                    continuation.yield(())
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    })

    static let testValue = QRCodeDumpMemoryWarningClient()
}
