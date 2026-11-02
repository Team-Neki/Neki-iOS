//
//  ServerLogRequest.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation

/// `POST /api/logs` 요청 본문과 크기 한도
enum ServerLogRequest {
    /// 요청 한 번에 담을 수 있는 최대 로그 수
    static let maxLogCount = 500
    /// 직렬화한 로그 한 건의 최대 크기(1,000KiB)
    static let maxLogBytes = 1_000 * 1_024
    /// 요청 본문 전체의 최대 크기(4MiB)
    static let maxBodyBytes = 4 * 1_024 * 1_024

    private static let bodyPrefix = Data(#"{"platform":"IOS","logs":["#.utf8)
    private static let bodySuffix = Data("]}".utf8)
    private static let separator = Data(",".utf8)

    /// 직렬화해 둔 로그를 그대로 이어 붙여 요청 본문을 만듭니다.
    /// - Note: 저장한 바이트를 다시 인코딩하지 않으므로, 재전송해도 같은 로그가 갑니다.
    static func body(logs: [Data]) -> Data {
        var body = bodyPrefix
        for (index, log) in logs.enumerated() {
            if index > 0 { body.append(separator) }
            body.append(log)
        }
        body.append(bodySuffix)
        return body
    }

    /// 앞에서부터 요청 하나에 담을 수 있는 로그 수
    /// - Note: 로그 한 건은 저장할 때 `maxLogBytes` 이하로 거르므로, 첫 로그는 항상 들어갑니다.
    static func fittingCount(logSizes: [Int]) -> Int {
        var count = 0
        var bodySize = bodyPrefix.count + bodySuffix.count
        for size in logSizes.prefix(maxLogCount) {
            let nextSize = bodySize + size + (count > 0 ? separator.count : 0)
            guard nextSize <= maxBodyBytes else { break }
            bodySize = nextSize
            count += 1
        }
        return count
    }

    static func isWithinLogLimit(_ log: Data) -> Bool {
        log.count <= maxLogBytes
    }
}
