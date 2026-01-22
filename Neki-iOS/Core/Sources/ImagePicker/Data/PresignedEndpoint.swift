//
//  PresignedEndpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public struct PresignedEndpoint: Endpoint {
    public var authorizationType: AuthorizationType = .bearer

    public var contentType: HTTPContentType = .json
    
    public var baseURL: String {
        guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            return NetworkError.invalidURLError.localizedDescription
        }
        return urlString
    }
    
    public var path: String = "media/upload"
    
    public var method: HTTPMethodType = .post
    
    public var body: Encodable?
    
    public init(requests: PresignedURLRequestDTO) {
        self.body = requests
    }
}
