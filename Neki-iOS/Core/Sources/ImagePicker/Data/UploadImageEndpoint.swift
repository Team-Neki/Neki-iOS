//
//  UploadImageEndpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public struct UploadImageEndpoint: Endpoint {
    public var baseURL: String
    public var path: String = ""
    public var method: HTTPMethodType = .put
    public var authorizationType: AuthorizationType = .none
    public var contentType: HTTPContentType
    
    public var body: Encodable?
    
    public init(presignedUrl: String, imageData: Data, contentType: String) {
        self.baseURL = presignedUrl
        self.body = imageData
        self.contentType = .custom(contentType)
    }
}
