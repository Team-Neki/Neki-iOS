//
//  ServerLogStorageTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogStorageTests {
    @Test("파일 이름은 발생 시각과 순번을 0으로 채워 이름 순서가 발생 순서가 되게 한다")
    func fileName_padsOrderingKeys() {
        let event = makeStoredEvent(occurredAt: 1_793_610_697_473, sequenceNumber: 2, id: "event-a")

        #expect(event.fileName == "1793610697473-000000002-event-a.json")
        #expect(ServerLogStoredEvent.occurredAtMilliseconds(fileName: event.fileName) == 1_793_610_697_473)
    }

    @Test("쓴 순서와 관계없이 발생 시각·순번 순으로 읽는다")
    func events_areSortedByOccurrence() async throws {
        try await withStorage { storage, _ in
            try await storage.write(makeStoredEvent(occurredAt: 2_000, sequenceNumber: 1, id: "c"))
            try await storage.write(makeStoredEvent(occurredAt: 1_000, sequenceNumber: 2, id: "b"))
            try await storage.write(makeStoredEvent(occurredAt: 1_000, sequenceNumber: 1, id: "a"))

            #expect(await storage.events().map(\.eventID) == ["a", "b", "c"])
        }
    }

    @Test("저장한 직렬화 결과를 바꾸지 않고 돌려준다")
    func events_returnStoredBytes() async throws {
        try await withStorage { storage, _ in
            let event = makeStoredEvent(occurredAt: 1_000, sequenceNumber: 1, id: "a", userID: nil)

            try await storage.write(event)

            #expect(await storage.events() == [event])
        }
    }

    @Test("지운 로그는 다시 읽히지 않는다")
    func remove_deletesOnlyGivenEvents() async throws {
        try await withStorage { storage, _ in
            let events = (1...3).map { makeStoredEvent(occurredAt: Int64($0) * 1_000, sequenceNumber: 1, id: "\($0)") }
            for event in events { try await storage.write(event) }

            await storage.remove([events[0], events[2]])

            #expect(await storage.events() == [events[1]])
        }
    }

    @Test("보관 중인 로그 수와 가장 오래된 발생 시각, 아직 남아 있는 로그를 알려 준다")
    func statusAndExisting_reflectStoredFiles() async throws {
        try await withStorage { storage, _ in
            let events = (1...3).map { makeStoredEvent(occurredAt: Int64($0) * 1_000, sequenceNumber: 1, id: "\($0)") }
            for event in events { try await storage.write(event) }

            await storage.remove([events[0]])
            let status = await storage.status()

            #expect(status.count == 2)
            #expect(status.oldestOccurredAtMilliseconds == 2_000)
            #expect(await storage.existing(events) == [events[1], events[2]])
        }
    }

    @Test("읽지 못한 파일과 다른 스키마 버전의 파일은 격리하고 나머지는 읽는다")
    func events_quarantineUnreadableFiles() async throws {
        try await withStorage { storage, directory in
            let valid = makeStoredEvent(occurredAt: 3_000, sequenceNumber: 1, id: "valid")
            try await storage.write(valid)
            let broken = "0000000001000-000000001-broken.json"
            try Data("not json".utf8).write(to: directory.appendingPathComponent(broken))
            let otherVersion = makeStoredEvent(occurredAt: 2_000, sequenceNumber: 1, id: "other-version")
            let encoded = try JSONEncoder().encode(otherVersion)
            var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            object["version"] = 99
            try JSONSerialization.data(withJSONObject: object).write(to: directory.appendingPathComponent(otherVersion.fileName))

            let events = await storage.events()
            let quarantined = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent(".quarantine").path)

            #expect(events == [valid])
            #expect(Set(quarantined) == [broken, otherVersion.fileName])
            #expect(await storage.events() == [valid])
        }
    }

    @Test("보관 기간이 지난 로그를 지운다")
    func prune_removesExpiredEvents() async throws {
        var limits = ServerLogStorage.Limits()
        limits.retention = 1_000
        try await withStorage(limits: limits) { storage, _ in
            for (index, occurredAt) in [Int64(0), 500, 2_000].enumerated() {
                try await storage.write(makeStoredEvent(occurredAt: occurredAt, sequenceNumber: 1, id: "\(index)"))
            }

            let removedCount = await storage.prune(now: 2_500)

            #expect(removedCount == 2)
            #expect(await storage.events().map(\.eventID) == ["2"])
        }
    }

    @Test("최대 개수를 넘으면 오래된 로그부터 지운다")
    func prune_removesOldestOverCountLimit() async throws {
        var limits = ServerLogStorage.Limits()
        limits.maxEventCount = 2
        try await withStorage(limits: limits) { storage, _ in
            for index in 1...3 {
                try await storage.write(makeStoredEvent(occurredAt: Int64(index) * 1_000, sequenceNumber: 1, id: "\(index)"))
            }

            let removedCount = await storage.prune(now: 3_000)

            #expect(removedCount == 1)
            #expect(await storage.events().map(\.eventID) == ["2", "3"])
        }
    }

    @Test("전체 크기가 한도를 넘으면 오래된 로그부터 지운다")
    func prune_removesOldestOverSizeLimit() async throws {
        try await withStorage { storage, directory in
            let events = (1...3).map { makeStoredEvent(occurredAt: Int64($0) * 1_000, sequenceNumber: 1, id: "\($0)") }
            for event in events { try await storage.write(event) }
            let fileSize = try #require(
                try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(events[0].fileName).path)[.size] as? Int
            )
            var limits = ServerLogStorage.Limits()
            limits.maxTotalBytes = fileSize * 2
            let limitedStorage = ServerLogStorage(directory: directory, limits: limits)

            let removedCount = await limitedStorage.prune(now: 3_000)

            #expect(removedCount == 1)
            #expect(await limitedStorage.events().map(\.eventID) == ["2", "3"])
        }
    }

    @Test("격리한 파일도 보관 기간이 지나면 지운다")
    func prune_removesExpiredQuarantinedFiles() async throws {
        var limits = ServerLogStorage.Limits()
        limits.retention = 1_000
        try await withStorage(limits: limits) { storage, directory in
            try await storage.write(makeStoredEvent(occurredAt: 10_000, sequenceNumber: 1, id: "valid"))
            let broken = directory.appendingPathComponent("0000000009000-000000001-broken.json")
            try Data("not json".utf8).write(to: broken)
            _ = await storage.events()
            let quarantined = directory.appendingPathComponent(".quarantine/\(broken.lastPathComponent)")
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: quarantined.path)

            await storage.prune(now: 10_000)

            #expect(FileManager.default.fileExists(atPath: quarantined.path) == false)
        }
    }

    @Test("저장 폴더를 iCloud 백업에서 뺀다")
    func write_excludesDirectoryFromBackup() async throws {
        try await withStorage { storage, directory in
            try await storage.write(makeStoredEvent(occurredAt: 1_000, sequenceNumber: 1, id: "a"))

            let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])

            #expect(values.isExcludedFromBackup == true)
        }
    }
}


// MARK: - Helpers

private extension ServerLogStorageTests {
    func withStorage(
        limits: ServerLogStorage.Limits = ServerLogStorage.Limits(),
        operation: (ServerLogStorage, URL) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ServerLogStorageTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await operation(ServerLogStorage(directory: directory, limits: limits), directory)
    }

    func makeStoredEvent(occurredAt: Int64, sequenceNumber: Int, id: String, userID: String? = "1") -> ServerLogStoredEvent {
        let event = ServerLogEvent(
            eventID: id,
            eventType: "app_open",
            eventProperties: [:],
            occurredAtMilliseconds: occurredAt,
            sessionID: occurredAt,
            sequenceNumber: sequenceNumber,
            deviceID: "device-1",
            userIDAtOccurrence: userID,
            appVersion: "1.2.9",
            context: [:]
        )
        return ServerLogStoredEvent(event: event, log: Data(#"{"eventId":"\#(id)"}"#.utf8))
    }
}
