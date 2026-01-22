//
//  ParsingStrategyType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

enum ParsingStrategyType {
    /// URL 계산/조립 방식
    case native
    /// 웹페이지 크롤링 방식
    case htmlCrawling
    /// 브랜드 다운로드 페이지를 웹뷰로 표시, 다운로드 및 공유 유도 방식
    case webView
}
