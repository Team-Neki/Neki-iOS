//
//  DefaultQRCodeDumpRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import CoreFoundation
import Dependencies
import Foundation

struct DefaultQRCodeDumpRepository: QRCodeDumpRepository {
    @Dependency(\.networkProvider) private var networkProvider

    func prepareHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument {
        guard Self.isAllowedNetworkURL(sourceURL) else { throw QRCodeDumpError.invalidURL }

        let endpoint = QRCodeDumpDownloadEndpoint(sourceURL: sourceURL)
        let (data, response) = try await networkProvider.request(endpoint: endpoint)
        guard data.isEmpty == false else { throw QRCodeDumpError.invalidResponse }
        guard let finalURL = response.url,
              Self.isAllowedNetworkURL(finalURL)
        else { throw QRCodeDumpError.invalidRedirectURL }

        let comments = Self.comments(sourceURL: sourceURL, finalURL: finalURL)
        let commentData = Data(comments.utf8)
        let maximumBodySize = Int(QRCodeDumpDownloadEndpoint.maximumBodySize)
        guard commentData.count < maximumBodySize else { throw QRCodeDumpError.responseTooLarge }

        let availableHTMLSize = maximumBodySize - commentData.count
        let htmlData = try Self.utf8Data(
            from: data,
            encodingName: response.textEncodingName,
            maximumSize: availableHTMLSize
        )
        var uploadData = commentData
        uploadData.append(htmlData)
        guard uploadData.count <= maximumBodySize else { throw QRCodeDumpError.responseTooLarge }

        return QRCodeDumpDocument(data: uploadData)
    }

    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket {
        let response: BaseResponseDTO<QRCodeDumpUploadTicketDTO.Response> = try await networkProvider.request(endpoint: QRCodeScannerEndpoint.issueDumpUploadTicket)
        guard let ticket = response.data?.toEntity() else {
            throw QRCodeDumpError.missingUploadTicket
        }
        return ticket
    }

    func upload(_ document: QRCodeDumpDocument, with ticket: QRCodeDumpUploadTicket) async throws {
        guard Int64(document.data.count) <= QRCodeDumpDownloadEndpoint.maximumBodySize else {
            throw QRCodeDumpError.responseTooLarge
        }
        guard let method = HTTPMethodType(rawValue: ticket.method.uppercased()) else {
            throw QRCodeDumpError.unsupportedUploadMethod
        }
        guard URL(string: ticket.uploadTicket) != nil else {
            throw QRCodeDumpError.invalidUploadTicket
        }

        let endpoint = QRCodeDumpUploadEndpoint(
            presignedURL: ticket.uploadTicket,
            uploadMethod: method,
            uploadContentType: ticket.contentType,
            uploadData: document.data
        )
        try await networkProvider.requestVoid(endpoint: endpoint)
    }
}

private extension DefaultQRCodeDumpRepository {
    static func comments(sourceURL: URL, finalURL: URL) -> String {
        var comments = "<!-- source: \(sourceURL.absoluteString) -->\n"
        if finalURL != sourceURL {
            comments += "<!-- final: \(finalURL.absoluteString) -->\n"
        }
        return comments
    }

    static func utf8Data(from data: Data, encodingName: String?, maximumSize: Int) throws -> Data {
        guard data.count <= maximumSize else { throw QRCodeDumpError.responseTooLarge }
        guard let encodingName else { return data }
        guard let encoding = stringEncoding(forIANAName: encodingName) else {
            throw QRCodeDumpError.stringDecodingFailed
        }
        guard encoding != .utf8 else { return data }

        guard let html = String(data: data, encoding: encoding) else {
            throw QRCodeDumpError.stringDecodingFailed
        }
        let htmlData = Data(html.utf8)
        guard htmlData.count <= maximumSize else { throw QRCodeDumpError.responseTooLarge }
        return htmlData
    }

    static func stringEncoding(forIANAName name: String) -> String.Encoding? {
        let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard encoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }

    static func isAllowedNetworkURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
