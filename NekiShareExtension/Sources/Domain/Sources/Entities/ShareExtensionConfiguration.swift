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
    private enum InfoKey {
        static let appGroupID = "NEKI_APP_GROUP_ID"
        static let urlScheme = "NEKI_URL_SCHEME"
    }

    let appGroupID: String
    let deepLinkURL: URL?
    
    init(bundle: Bundle = .main) {
        guard let appGroupID = bundle.object(forInfoDictionaryKey: InfoKey.appGroupID) as? String,
              let scheme = bundle.object(forInfoDictionaryKey: InfoKey.urlScheme) as? String,
              appGroupID.isEmpty == false,
              scheme.isEmpty == false
        else {
            self.appGroupID = ""
            self.deepLinkURL = nil
            return
        }

        self.appGroupID = appGroupID
        
        var components = URLComponents(string: "\(scheme)://shareExtension")
        components?.queryItems = [URLQueryItem(name: "appGroupID", value: appGroupID)]
        self.deepLinkURL = components?.url
    }
}
