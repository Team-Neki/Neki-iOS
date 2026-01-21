//
//  MyPageCoordinatorView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import SwiftUI
import ComposableArchitecture

struct MyPageCoordinatorView: View {
    @Bindable var store: StoreOf<MyPageCoordinator>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            MyPageView(store: store.scope(state: \.root, action: \.root))
        } destination: { childStore in
            switch childStore.case {
            case let .deviceAuthorizationPreference(store):
                DeviceAuthorizationPreferenceView(store: store)
            case let .accountPreference(store):
                AccountPreferenceView(store: store)
            case let .profileEdit(store):
                ProfileEditView(store: store)
            }
        }
    }
}

#Preview {
    MyPageCoordinatorView(store: .init(initialState: MyPageCoordinator.State(), reducer: { MyPageCoordinator() }))
}
