//
//  QRCodeParsingStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

protocol QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { get }
    var supportedHosts: [String] { get }
    
    func canHandle(host: String) -> Bool
    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult
}

extension QRCodeParsingStrategy {
    func canHandle(host: String) -> Bool {
        let host = host.lowercased()
        return supportedHosts.contains {
            let supportedHost = $0.lowercased()
            return host == supportedHost || host.hasSuffix(".\(supportedHost)")
        }
    }
}
