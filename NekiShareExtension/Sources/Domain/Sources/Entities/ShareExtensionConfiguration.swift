//
//  ShareExtensionConfiguration.swift
//  NekiShareExtension
//
//  Created by SwainYun on 3/20/26.
//

import Foundation

enum ShareExtensionConfigurationError: Error {
    case invalidConfiguration
}

struct ShareExtensionConfiguration {
    let appGroupID: String
    let deepLinkURL: URL?
    
    init(bundle: Bundle = .main) {
        #if DEBUG
        self.appGroupID = "group.com.Neki-dev.Share-Extension"
        let scheme = "neki-dev"
        #else
        self.appGroupID = "group.com.OneTen.Neki-iOS.Share-Extension"
        let scheme = "neki"
        #endif
        
        var components = URLComponents(string: "\(scheme)://shareExtension")
        components?.queryItems = [URLQueryItem(name: "appGroupID", value: appGroupID)]
        self.deepLinkURL = components?.url
    }
}
