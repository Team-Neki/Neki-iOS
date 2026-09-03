//
//  UploadError.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

public enum UploadError: Error, Equatable, Sendable {
    case presignedUrlFailed
    case uploadFailed
    case authenticationRequired
}
