//
//  ScrapPoseDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

public enum ScrapPoseDTO {
    public struct Request: Encodable {
        let scrap: Bool
        
        init(toBe: Bool) { scrap = toBe }
    }
    
    public typealias Response = EmptyData
}
