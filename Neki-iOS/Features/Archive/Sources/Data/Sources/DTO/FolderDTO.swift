//
//  FolderDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/28/26.
//

import Foundation

public enum FolderDTO {
    public struct Request: Encodable {
        let name: String
    }
    
    public struct Response: Decodable {
        let folderId: Int
    }
}
