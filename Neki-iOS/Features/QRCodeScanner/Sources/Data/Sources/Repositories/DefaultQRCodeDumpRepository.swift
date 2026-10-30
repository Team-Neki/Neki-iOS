//
//  DefaultQRCodeDumpRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import Dependencies
import os

actor DefaultQRCodeDumpRepository: QRCodeDumpRepository {
    @Dependency(\.networkProvider) private var networkProvider
    @Dependency(\.fileTransferProvider) private var fileTransferProvider
    @Dependency(\.qrCodeDumpStorage) private var storage

    private let fileManager = FileManager.default
    private var documentURLs: [UUID: URL] = [:]
    private var hasCleanedStaleFiles = false

    func prepareHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument {
        guard Self.isAllowedNetworkURL(sourceURL) else { throw QRCodeDumpError.invalidURL }
        try Task.checkCancellation()
        try prepareDumpDirectory()

        let id = UUID()
        let sourceFileURL = dumpDirectoryURL.appendingPathComponent("\(id.uuidString).source.partial")
        let partialUploadFileURL = dumpDirectoryURL.appendingPathComponent("\(id.uuidString).html.partial")
        let uploadFileURL = dumpDirectoryURL.appendingPathComponent("\(id.uuidString).html")

        do {
            let maximumBodySize = try maximumSourceBodySize()
            guard fileManager.createFile(atPath: sourceFileURL.path, contents: nil),
                  fileManager.createFile(atPath: partialUploadFileURL.path, contents: nil)
            else { throw QRCodeDumpError.fileCreationFailed }

            let endpoint = QRCodeDumpDownloadEndpoint(sourceURL: sourceURL, maximumBodySize: maximumBodySize)
            let response = try await fileTransferProvider.request(endpoint: endpoint, writingTo: sourceFileURL)
            guard let finalURL = response.url,
                  Self.isAllowedNetworkURL(finalURL)
            else { throw QRCodeDumpError.invalidRedirectURL }
            let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceFileURL.path)
            guard let sourceByteCount = sourceAttributes[.size] as? NSNumber else {
                throw QRCodeDumpError.missingFileSize
            }

            try Task.checkCancellation()
            try QRCodeDumpDocumentWriter.write(
                sourceFileURL: sourceFileURL,
                uploadFileURL: partialUploadFileURL,
                sourceURL: sourceURL,
                finalURL: finalURL,
                encodingName: response.textEncodingName
            )
            try Task.checkCancellation()
            try fileManager.removeItem(at: sourceFileURL)

            let attributes = try fileManager.attributesOfItem(atPath: partialUploadFileURL.path)
            guard let byteCount = attributes[.size] as? NSNumber else {
                throw QRCodeDumpError.missingFileSize
            }
            guard byteCount.int64Value <= QRCodeDumpDownloadEndpoint.maximumObjectSize else {
                throw QRCodeDumpError.responseTooLarge
            }
            try fileManager.moveItem(at: partialUploadFileURL, to: uploadFileURL)

            documentURLs[id] = uploadFileURL
            Logger.network.info("QR HTML dump 파일 준비 완료: host=\(sourceURL.host() ?? "unknown"), sourceBytes=\(sourceByteCount.int64Value), uploadBytes=\(byteCount.int64Value)")
            return QRCodeDumpDocument(
                id: id,
                sourceURL: sourceURL,
                finalURL: finalURL,
                byteCount: byteCount.int64Value
            )
        } catch {
            try? fileManager.removeItem(at: sourceFileURL)
            try? fileManager.removeItem(at: partialUploadFileURL)
            try? fileManager.removeItem(at: uploadFileURL)
            throw error
        }
    }

    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket {
        do {
            try Task.checkCancellation()
            let response: BaseResponseDTO<QRCodeDumpUploadTicketDTO.Response> = try await networkProvider.request(endpoint: QRCodeScannerEndpoint.issueDumpUploadTicket)
            guard let ticket = response.data?.toEntity() else {
                throw QRCodeDumpError.missingUploadTicket
            }
            return ticket
        } catch {
            throw error
        }
    }

    func upload(_ document: QRCodeDumpDocument, with ticket: QRCodeDumpUploadTicket) async throws {
        guard let fileURL = documentURLs[document.id] else { throw QRCodeDumpError.missingDocument }
        defer { removeDocument(id: document.id, fileURL: fileURL) }

        guard let method = HTTPMethodType(rawValue: ticket.method.uppercased()) else {
            throw QRCodeDumpError.unsupportedUploadMethod
        }
        guard URL(string: ticket.uploadTicket) != nil else { throw QRCodeDumpError.invalidUploadTicket }

        let endpoint = QRCodeDumpUploadEndpoint(
            presignedURL: ticket.uploadTicket,
            uploadMethod: method,
            uploadContentType: ticket.contentType
        )
        do {
            try Task.checkCancellation()
            try await fileTransferProvider.requestVoid(endpoint: endpoint, uploading: fileURL)
        } catch {
            throw error
        }
    }

    func discard(_ document: QRCodeDumpDocument) {
        guard let fileURL = documentURLs[document.id] else { return }
        removeDocument(id: document.id, fileURL: fileURL)
    }
}

private extension DefaultQRCodeDumpRepository {
    static let processSessionIdentifier = UUID().uuidString
    static let maximumUTF8ExpansionFactor: Int64 = 3
    // 원본 1배 + UTF-8 변환본 최대 3배 + 동시 파일 작업을 위한 1배의 여유 공간입니다.
    static let storageSafetyFactor = maximumUTF8ExpansionFactor + 2

    var dumpRootURL: URL {
        storage.temporaryDirectoryURL.appendingPathComponent("neki-qr-dumps", isDirectory: true)
    }

    var dumpDirectoryURL: URL {
        dumpRootURL.appendingPathComponent(Self.processSessionIdentifier, isDirectory: true)
    }

    func prepareDumpDirectory() throws {
        try fileManager.createDirectory(at: dumpRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dumpDirectoryURL, withIntermediateDirectories: true)
        guard hasCleanedStaleFiles == false else { return }

        let sessionDirectoryURLs = try fileManager.contentsOfDirectory(at: dumpRootURL, includingPropertiesForKeys: nil)
        sessionDirectoryURLs
            .filter { $0.lastPathComponent != Self.processSessionIdentifier }
            .forEach { try? fileManager.removeItem(at: $0) }
        hasCleanedStaleFiles = true
    }

    func maximumSourceBodySize() throws -> Int64 {
        guard let capacity = try storage.availableCapacity(dumpDirectoryURL), capacity > 0 else {
            throw QRCodeDumpError.unavailableStorageCapacity
        }
        let deviceLimit = capacity / Self.storageSafetyFactor
        guard deviceLimit > 0 else { throw QRCodeDumpError.insufficientStorageCapacity }
        return min(deviceLimit, QRCodeDumpDownloadEndpoint.maximumObjectSize)
    }

    func removeDocument(id: UUID, fileURL: URL) {
        documentURLs[id] = nil
        try? fileManager.removeItem(at: fileURL)
    }

    static func isAllowedNetworkURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

}
