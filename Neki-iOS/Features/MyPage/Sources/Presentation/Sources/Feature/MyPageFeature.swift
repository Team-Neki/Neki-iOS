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
        var user: User
    }
    
    enum Action {
        case cellTapped(SectionCellItem)
        case profileTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            default:
                return .none
            }
        }
    }
}


// MARK: - MyPageFeature + Nested Types

extension MyPageFeature {
    enum SectionItem: String {
        case authorizationSettings = "권한"
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
        case deviceAuthorization = "권한 설정하기"
        case support = "Neki에 문의하기"
        case termsOfService = "이용약관"
        case privacyPolicy = "개인정보 처리방침"
        case version = "앱 버전 정보"
        
        var id: Int { self.hashValue }
        
        var hasLink: Bool { self != .version }
        
        var title: String { self.rawValue }
    }
}
