//
//  QRCodeDumpSession.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import Foundation
import Dependencies
import os

actor QRCodeDumpSession {
    @Dependency(\.qrCodeDumpMemoryWarningClient) private var memoryWarningClient

    private var reservedURLs: Set<URL> = []
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var taskURLs: [UUID: URL] = [:]
    private var tail: Task<Void, Never>?
    private var memoryWarningTask: Task<Void, Never>?

    func reserve(_ url: URL) -> Bool {
        reservedURLs.insert(url).inserted
    }

    func enqueue(url: URL, work: @escaping @Sendable () async -> Bool) {
        let id = UUID()
        let previous = tail
        let task = Task(priority: .utility) { [weak self] in
            await previous?.value
            guard Task.isCancelled == false else {
                await self?.finish(id: id, url: url, succeeded: false)
                return
            }
            let succeeded = await work()
            await self?.finish(id: id, url: url, succeeded: succeeded)
        }
        tasks[id] = task
        taskURLs[id] = url
        tail = task
        startMemoryWarningObservationIfNeeded()
    }

    func finish(id: UUID, url: URL, succeeded: Bool) {
        guard tasks.removeValue(forKey: id) != nil else { return }
        taskURLs[id] = nil
        if succeeded == false { reservedURLs.remove(url) }
        if tasks.isEmpty { stopMemoryWarningObservation() }
    }

    func cancelAllForMemoryWarning() {
        let cancelledURLs = Set(taskURLs.values)
        tasks.values.forEach { $0.cancel() }
        cancelledURLs.forEach { reservedURLs.remove($0) }
        tasks.removeAll()
        taskURLs.removeAll()
        tail = nil
        stopMemoryWarningObservation()
        Logger.network.notice("QR HTML dump 메모리 경고 취소: count=\(cancelledURLs.count)")
    }

    func startMemoryWarningObservationIfNeeded() {
        guard memoryWarningTask == nil else { return }
        let memoryWarnings = memoryWarningClient.events()
        memoryWarningTask = Task { [weak self] in
            for await _ in memoryWarnings {
                await self?.cancelAllForMemoryWarning()
            }
        }
    }

    func stopMemoryWarningObservation() {
        memoryWarningTask?.cancel()
        memoryWarningTask = nil
    }
}
