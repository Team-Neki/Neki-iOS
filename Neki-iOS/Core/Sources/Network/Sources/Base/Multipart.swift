//
//  Multipart.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/14/26.
//

import Foundation

fileprivate extension Data {
    mutating func append(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { throw MultipartError.unsupportedValueType }
        append(data)
    }
}

public protocol MultipartItem {
    func append(to builder: inout MultipartItemBuilder) throws
}

public enum MultipartError: Error {
    case unsupportedValueType
    case invalidBody
}

/// 단순한 키-값 파라미터 멀티파트 아이템
public struct MultipartFormField: MultipartItem {
    let name: String
    let value: Any
    
    public func append(to builder: inout MultipartItemBuilder) throws {
        let stringValue: String
        
        switch value {
        case let string as String: stringValue = string
        case let int as Int: stringValue = String(int)
        case let bool as Bool: stringValue = bool ? "true" : "false"
        case let double as Double: stringValue = String(double)
            // TODO: Date 등 다양한 타입 지원이 필요하면 이곳에 케이스 추가
        default: throw MultipartError.unsupportedValueType
        }
        
        try builder.append(value: stringValue, name: name)
    }
}

/// 파일 데이터 멀티파트 아이템
public struct MultipartFile: MultipartItem {
    let name: String
    let data: Data
    let fileName: String
    let mimeType: String

    public func append(to builder: inout MultipartItemBuilder) throws {
        try builder.append(data: data, name: name, fileName: fileName, mimeType: mimeType)
    }
}

public struct MultipartItemBuilder {
    private let boundary: String
    private var body = Data()
    
    public init(boundary: String) { self.boundary = boundary }
    
    /// 일반 텍스트 파라미터 추가
    public mutating func append(value: String, name: String) throws {
        try body.append("--\(boundary)\r\n")
        try body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
        try body.append("\r\n") // 헤더와 본문 사이 공백
        try body.append(value)
        try body.append("\r\n")
    }
    
    /// 파일 데이터(이미지 등) 추가
    public mutating func append(data: Data, name: String, fileName: String, mimeType: String) throws {
        try body.append("--\(boundary)\r\n")
        try body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        try body.append("Content-Type: \(mimeType)\r\n")
        try body.append("\r\n") // 헤더와 본문 사이 공백
        body.append(data)
        try body.append("\r\n")
    }
    
    /// 최종 Body 데이터 생성 (Closing Boundary 추가)
    public func finalize() throws -> Data {
        var finalBody = body
        try finalBody.append("--\(boundary)--\r\n") // 끝을 알리는 -- 추가
        return finalBody
    }
}
