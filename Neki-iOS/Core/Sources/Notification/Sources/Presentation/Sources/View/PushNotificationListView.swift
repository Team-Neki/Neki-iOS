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
            content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.gray25)
            .nekiToolbar {
                NekiToolBar.close { store.send(.closeButtonTapped) }
            } center: {
                NekiToolBar.textCenter("알림")
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

private extension PushNotificationListView {
    @ViewBuilder
    var content: some View {
        if store.isLoading {
            ProgressView()
        } else if store.notifications.isEmpty {
            unavailableView
        } else {
            notificationList
        }
    }

    var unavailableView: some View {
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
    }

    var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.notifications) { notification in
                    notificationCell(notification)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    func notificationCell(_ notification: PushNotificationListItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notification.title)
                .nekiFont(.body16SemiBold)
                .foregroundStyle(.gray900)

            Text(notification.body)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PushNotificationListView(
        store: Store(initialState: PushNotificationListFeature.State()) {
            PushNotificationListFeature()
        }
    )
}
