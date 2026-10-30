//
//  QRCodeDumpSession.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import Foundation

actor QRCodeDumpSession {
    private var reservedURLs: Set<URL> = []
    private var tail: Task<Void, Never>?

    func reserve(_ url: URL) -> Bool {
        reservedURLs.insert(url).inserted
    }

    func enqueue(url: URL, work: @escaping @Sendable () async -> Bool) {
        let previous = tail
        let task = Task(priority: .utility) { [weak self] in
            await previous?.value
            let succeeded = await work()
            await self?.finish(url: url, succeeded: succeeded)
        }
        tail = task
    }

    func finish(url: URL, succeeded: Bool) {
        if succeeded == false { reservedURLs.remove(url) }
    }
}
