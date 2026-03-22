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
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.OneTen.Neki-iOS.Share-Extension"
        self.appGroupID = "group.\(bundleIdentifier)"
        
        var components = URLComponents(string: "neki://shareExtension")
        components?.queryItems = [URLQueryItem(name: "appGroupID", value: appGroupID)]
        self.deepLinkURL = components?.url
    }
}
