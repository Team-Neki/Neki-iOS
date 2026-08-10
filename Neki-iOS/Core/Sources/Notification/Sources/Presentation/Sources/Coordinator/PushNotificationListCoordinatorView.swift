//
//  PushNotificationListCoordinatorView.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/23/26.
//

import SwiftUI
import ComposableArchitecture

struct PushNotificationListCoordinatorView: View {
    let store: StoreOf<PushNotificationListFeature>

    var body: some View {
        NavigationStack {
            PushNotificationListView(store: store)
                .navigationBarBackButtonHidden()
        }
    }
}
