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
        #else
        self.appGroupID = "group.com.OneTen.Neki-iOS.Share-Extension"
        #endif
        
        var components = URLComponents(string: "neki://shareExtension")
        components?.queryItems = [URLQueryItem(name: "appGroupID", value: appGroupID)]
        self.deepLinkURL = components?.url
    }
}
