//
//  PushNotificationListView.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import SwiftUI
import ComposableArchitecture

struct PushNotificationListView: View {
    let store: StoreOf<PushNotificationListFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                Spacer()

                VStack(spacing: 12) {
                    Image(.iconEmpty)

                    Text("아직 받은 알림이 없어요.")
                        .nekiFont(.body16Medium)
                        .foregroundStyle(.gray500)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(.gray25)
            .nekiToolbar {
                NekiToolBar.close { store.send(.closeButtonTapped) }
            } center: {
                NekiToolBar.textCenter("알림")
            }
        }
    }
}

#Preview {
    PushNotificationListView(
        store: Store(initialState: PushNotificationListFeature.State()) {
            PushNotificationListFeature()
        }
    )
}
