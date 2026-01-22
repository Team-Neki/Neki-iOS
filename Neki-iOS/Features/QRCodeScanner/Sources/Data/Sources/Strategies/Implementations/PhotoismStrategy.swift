//
//  PhotoismStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation

struct PhotoismStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .webView }
    
    func canHandle(host: String) -> Bool { PhotoBoothBrand.photoism.hostKeywords.contains(host) }
    
    func parse(_ url: URL, networkProvider: any NetworkProvider) async throws(QRParseError) -> ParsedQRResult { throw .fallbackToWebView(url) }
}
