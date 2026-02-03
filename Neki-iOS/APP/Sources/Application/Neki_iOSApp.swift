//
//  Neki_iOSApp.swift
//  Neki-iOS
//
//  Created by OneTen on 12/21/25.
//

import SwiftUI
import ComposableArchitecture
import KakaoSDKCommon
import KakaoSDKAuth

@main
struct Neki_iOSApp: App {
    let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
    }
    
    init() {
        let kakaoAppKey = Bundle.main.infoDictionary?["KAKAO_LOGIN_NATIVE_APP_KEY"] as? String ?? ""
        KakaoSDK.initSDK(appKey: kakaoAppKey)
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(store: store)
                .onOpenURL { url in
                    if (AuthApi.isKakaoTalkLoginUrl(url)) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
