//
//  DefaultQRCodeDumpRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import CoreFoundation
import Dependencies

actor DefaultQRCodeDumpRepository: QRCodeDumpRepository {
    private let networkProvider: any NetworkProvider

    init(networkProvider: (any NetworkProvider)? = nil) {
        @Dependency(\.networkProvider) var defaultNetworkProvider
        self.networkProvider = networkProvider ?? defaultNetworkProvider
    }

    func fetchHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument {
        guard Self.isAllowedNetworkURL(sourceURL) else { throw QRCodeDumpError.invalidURL }

        let (data, response) = try await networkProvider.request(endpoint: QRCodeScannerEndpoint.fetchDump(url: sourceURL))
        guard data.isEmpty == false else { throw QRCodeDumpError.invalidResponse }

        guard let finalURL = response.url,
              Self.isAllowedNetworkURL(finalURL)
        else { throw QRCodeDumpError.invalidRedirectURL }

        let htmlData = try Self.utf8Data(from: data, encodingName: response.textEncodingName)
        return QRCodeDumpDocument(
            sourceURL: sourceURL,
            finalURL: finalURL,
            htmlData: htmlData
        )
    }

    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket {
        let response: BaseResponseDTO<QRCodeDumpUploadTicketDTO.Response> = try await networkProvider.request(endpoint: QRCodeScannerEndpoint.issueDumpUploadTicket)
        guard let ticket = response.data?.toEntity() else { throw QRCodeDumpError.missingUploadTicket }
        return ticket
    }

    func upload(_ data: Data, with ticket: QRCodeDumpUploadTicket) async throws {
        guard let method = HTTPMethodType(rawValue: ticket.method.uppercased()) else {
            throw QRCodeDumpError.unsupportedUploadMethod
        }
        guard URL(string: ticket.uploadTicket) != nil else { throw QRCodeDumpError.invalidUploadTicket }

        let endpoint = QRCodeScannerEndpoint.uploadDump(
            presignedURL: ticket.uploadTicket,
            method: method,
            contentType: ticket.contentType,
            data: data
        )
        try await networkProvider.requestVoid(endpoint: endpoint)
    }
}

fileprivate extension DefaultQRCodeDumpRepository {
    static func isAllowedNetworkURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    static func utf8Data(from data: Data, encodingName: String?) throws -> Data {
        guard let encodingName,
              let encoding = stringEncoding(forIANAName: encodingName),
              encoding != .utf8
        else { return data }

        guard let html = String(data: data, encoding: encoding) else {
            throw QRCodeDumpError.stringDecodingFailed
        }
        return Data(html.utf8)
    }

    static func stringEncoding(forIANAName name: String) -> String.Encoding? {
        let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard encoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }
}

private enum QRCodeDumpError: Error {
    case invalidURL
    case invalidResponse
    case invalidRedirectURL
    case stringDecodingFailed
    case missingUploadTicket
    case unsupportedUploadMethod
    case invalidUploadTicket
}
