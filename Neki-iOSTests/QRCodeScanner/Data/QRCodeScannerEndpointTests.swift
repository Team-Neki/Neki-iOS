//
//  QRCodeScannerEndpointTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Neki_iOS

struct QRCodeScannerEndpointTests {
    @Test("dump 다운로드는 QR URL을 변경 없이 GET 요청한다")
    func fetchDump_preservesSourceURL() throws {
        let sourceURL = try #require(URL(string: "http://example.com/a%2Fb?token=value#fragment"))
        let endpoint = QRCodeDumpDownloadEndpoint(sourceURL: sourceURL, maximumBodySize: 1_024)

        let request = try endpoint.asURLRequest()

        #expect(request.url == sourceURL)
        #expect(request.httpMethod == "GET")
        #expect(request.allowsConstrainedNetworkAccess == false)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(endpoint.networkLogPolicy == .metadataOnly)
        #expect(endpoint.responseConstraint == HTTPResponseConstraint(allowedContentTypes: [.html], maximumBodySize: 1_024))
    }

    @Test("dump ticket은 body 없이 Bearer POST로 요청한다")
    func issueDumpUploadTicket_usesBearerPostWithoutBody() {
        let endpoint = QRCodeScannerEndpoint.issueDumpUploadTicket

        #expect(endpoint.path == "media/qr-dumps/upload")
        #expect(endpoint.method == .post)
        #expect(endpoint.authorizationType == .bearer)
        #expect(endpoint.body == nil)
    }

    @Test("S3 PUT은 ticket의 URL과 Content-Type을 그대로 사용한다")
    func uploadDump_preservesTicketURLAndContentType() throws {
        let ticketURL = "https://example.com/a%2Fb/qr-dump.html?X-Amz-Credential=a%2Fb&X-Amz-Signature=signature"
        let endpoint = QRCodeDumpUploadEndpoint(
            presignedURL: ticketURL,
            uploadMethod: .put,
            uploadContentType: "text/html; charset=utf-8"
        )

        let request = try endpoint.asURLRequest()

        #expect(request.url?.absoluteString == ticketURL)
        #expect(request.httpMethod == "PUT")
        #expect(request.allowsConstrainedNetworkAccess == false)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/html; charset=utf-8")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(endpoint.networkLogPolicy == .metadataOnly)
    }

    @Test("S3 단일 PUT 한도를 업로드 파일 상한으로 사용한다")
    func uploadDump_appliesSinglePutLimit() {
        #expect(QRCodeDumpUploadEndpoint.maximumBodySize == 5 * 1_024 * 1_024 * 1_024)
    }
}
