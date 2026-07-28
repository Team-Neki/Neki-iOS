//
//  QRCodeParsingStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

protocol QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { get }
    
    func canHandle(host: String) -> Bool
    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult
}
