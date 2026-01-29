//
//  MyPageFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct MyPageFeature {
    @ObservableState
    struct State {
        // TODO: 유저정보 @Shared로 가져오거나 아니면 생성자로 주입, 일단은 임시값
        var user: User = User(nickname: "SwainYun", providerType: .kakao)
    }
    
    enum Action {
        case cellTapped(SectionCellItem)
        case profileTapped
    }
    
    @Dependency(\.openURL) private var openURL
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .cellTapped(item):
                // TODO: 노션 이동시키기
                return .none
                
            default:
                return .none
            }
        }
    }
}


// MARK: - MyPageFeature + Nested Types

extension MyPageFeature {
    enum SectionItem: String {
        case authorizationSettings = "권한 설정"
        case support = "서비스 정보 및 지원"
        
        var title: String { rawValue }
        
        var includedItems: [SectionCellItem] {
            switch self {
            case .authorizationSettings: return [.deviceAuthorization]
            case .support: return [.support, .termsOfService, .privacyPolicy, .version]
            }
        }
    }
    
    enum SectionCellItem: String, Identifiable {
        case deviceAuthorization = "기기 권한"
        case support = "Neki에 문의하기"
        case termsOfService = "이용약관"
        case privacyPolicy = "개인정보 처리방침"
        case version = "앱 버전 정보"
        
        var id: Int { self.hashValue }
        
        var hasLink: Bool { self != .version }
        
        var title: String { self.rawValue }
    }
}
