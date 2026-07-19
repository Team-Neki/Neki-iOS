//
//  PhotoismStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct PhotoismStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .webView }
    var supportedHosts: [String] { ["seobuk.kr"] }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.info("포토이즘 감지: 즉시 웹뷰 모드로 전환합니다.")
        throw .fallbackToWebView(url)
    }
}
