//
//  PushNotificationListView.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import SwiftUI
import ComposableArchitecture

struct PushNotificationListView: View {
    let store: StoreOf<PushNotificationListFeature>

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nekiLoading(
                isPresented: store.isLoading,
                message: "알림을 불러오고 있어요."
            )
            .nekiToolbar {
                NekiToolBar.back { store.send(.closeButtonTapped) }
            } center: {
                NekiToolBar.textCenter("알림")
            }
            .onAppear { store.send(.onAppear) }
    }
}

private extension PushNotificationListView {
    @ViewBuilder
    var content: some View {
        if store.isLoading {
            Color.clear
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
            VStack(alignment: .leading, spacing: 16) {
                Text("새로운 알림")
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray600)

                LazyVStack(spacing: 32) {
                    ForEach(store.notifications) { notification in
                        notificationCell(notification)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    func notificationCell(_ notification: PushNotificationListItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)

                Text(notification.body)
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray500)
            }
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let sentTime = notification.sentTime {
                PushNotificationSentTimeLabel(sentTime: sentTime)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}

private struct PushNotificationSentTimeLabel: View {
    let sentTime: PushNotificationSentTime

    var body: some View {
        TimelineView(PushNotificationSentTimeTimelineSchedule(sentTime: sentTime)) { context in
            Text(sentTime.relativeValue(to: context.date).displayText)
                .nekiFont(.caption12Medium)
                .foregroundStyle(.gray300)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

#Preview {
    PushNotificationListCoordinatorView(
        store: Store(initialState: PushNotificationListFeature.State()) {
            PushNotificationListFeature()
        }
    )
}
