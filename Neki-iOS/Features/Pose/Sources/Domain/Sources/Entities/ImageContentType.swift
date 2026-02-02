//
//  ImageContentType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

public enum ImageContentType: Sendable {
    case jpeg
    
    init?(_ rawValue: String) {
        switch rawValue {
        case "image/jpeg": self = .jpeg
        default: return nil
        }
    }
}
