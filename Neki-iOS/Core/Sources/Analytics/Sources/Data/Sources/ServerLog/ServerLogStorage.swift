//
//  ServerLogStorage.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation

/// 서버로 보내기 전까지 로그를 보관하는 디스크 저장소
/// - Note: Amplitude-Swift `PersistentStorage`처럼 Application Support 아래에 두고, iCloud 백업에서 빼고, 읽지 못한 파일은 격리합니다.
///   SDK와 달리 로그 한 건을 파일 하나로 씁니다. 배치를 회원별로 나누고, 응답에 따라 일부만 지우거나 나눠 보내야 하기 때문입니다.
actor ServerLogStorage {
    struct Limits: Sendable {
        /// 보관 기간(7일)
        var retention: Int64 = 7 * 24 * 60 * 60 * 1_000
        /// 보관할 최대 로그 수
        var maxEventCount = 5_000
        /// 보관할 로그 파일의 최대 전체 크기(10MiB)
        var maxTotalBytes = 10 * 1_024 * 1_024
    }

    private static let quarantineDirectoryName = ".quarantine"

    private let directory: URL
    private let limits: Limits

    init(directory: URL = ServerLogStorage.defaultDirectory, limits: Limits = Limits()) {
        self.directory = directory
        self.limits = limits
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("server-logs", isDirectory: true)
    }

    /// 로그 한 건을 원자적으로 씁니다. 첫 사용자 인증 뒤에는 잠긴 상태에서도 읽을 수 있게 둡니다.
    func write(_ event: ServerLogStoredEvent) throws {
        try prepareDirectory()
        let data = try JSONEncoder().encode(event)
        try data.write(
            to: directory.appendingPathComponent(event.fileName),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    /// 보관 중인 로그를 발생 시각·순번 순으로 돌려줍니다. 읽지 못한 파일은 격리합니다.
    func events() -> [ServerLogStoredEvent] {
        eventFiles().compactMap { file in
            guard let data = try? Data(contentsOf: file.url),
                  let event = try? JSONDecoder().decode(ServerLogStoredEvent.self, from: data),
                  event.version == ServerLogStoredEvent.currentVersion,
                  event.fileName == file.url.lastPathComponent
            else {
                quarantine(file.url)
                return nil
            }
            return event
        }
    }

    func remove(_ events: [ServerLogStoredEvent]) {
        for event in events {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(event.fileName))
        }
    }

    /// 보관 기간이 지났거나 수·크기 한도를 넘은 로그를 오래된 것부터 지웁니다.
    /// - Returns: 지운 로그 수
    @discardableResult
    func prune(now: Int64) -> Int {
        var files = eventFiles()
        let expiredCount = files.prefix { $0.occurredAtMilliseconds < now - limits.retention }.count
        var removing = Array(files.prefix(expiredCount))
        files.removeFirst(expiredCount)

        let overflowCount = max(0, files.count - limits.maxEventCount)
        removing += files.prefix(overflowCount)
        files.removeFirst(overflowCount)

        var totalBytes = files.reduce(0) { $0 + $1.size }
        while totalBytes > limits.maxTotalBytes, let oldest = files.first {
            removing.append(oldest)
            totalBytes -= oldest.size
            files.removeFirst()
        }

        for file in removing {
            try? FileManager.default.removeItem(at: file.url)
        }
        pruneQuarantine(now: now)
        return removing.count
    }
}


// MARK: - Files

private extension ServerLogStorage {
    struct EventFile {
        let url: URL
        let occurredAtMilliseconds: Int64
        let size: Int
    }

    var quarantineDirectory: URL {
        directory.appendingPathComponent(Self.quarantineDirectoryName, isDirectory: true)
    }

    func prepareDirectory() throws {
        guard FileManager.default.fileExists(atPath: directory.path) == false else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directory = directory
        try directory.setResourceValues(resourceValues)
    }

    /// 파일 이름(발생 시각·순번·이벤트 ID) 순으로 정렬한 로그 파일
    func eventFiles() -> [EventFile] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let occurredAt = ServerLogStoredEvent.occurredAtMilliseconds(fileName: url.lastPathComponent) else {
                    quarantine(url)
                    return nil
                }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return EventFile(url: url, occurredAtMilliseconds: occurredAt, size: size)
            }
    }

    func quarantine(_ url: URL) {
        let destination = quarantineDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination)
        if (try? FileManager.default.moveItem(at: url, to: destination)) == nil {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 격리한 파일도 보관 기간이 지나면 지웁니다.
    func pruneQuarantine(now: Int64) {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: quarantineDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let threshold = Date(timeIntervalSince1970: TimeInterval(now - limits.retention) / 1_000)
        for url in urls {
            let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modifiedAt, modifiedAt < threshold {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

/// 디스크에 보관하는 로그 한 건
/// - Note: 서버로 보낼 직렬화 결과(`log`)를 그대로 두고, 배치를 나누는 데 필요한 값만 따로 둡니다.
struct ServerLogStoredEvent: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let eventID: String
    let occurredAtMilliseconds: Int64
    let sequenceNumber: Int
    let userIDAtOccurrence: String?
    let log: Data

    init(event: ServerLogEvent, log: Data) {
        self.version = Self.currentVersion
        self.eventID = event.eventID
        self.occurredAtMilliseconds = event.occurredAtMilliseconds
        self.sequenceNumber = event.sequenceNumber
        self.userIDAtOccurrence = event.userIDAtOccurrence
        self.log = log
    }

    /// 이름 순서가 발생 시각·순번 순서가 되도록 숫자를 0으로 채웁니다.
    var fileName: String {
        String(format: "%013lld-%09ld-", occurredAtMilliseconds, sequenceNumber) + eventID + ".json"
    }

    static func occurredAtMilliseconds(fileName: String) -> Int64? {
        guard fileName.count > 13 else { return nil }
        return Int64(fileName.prefix(13))
    }
}
