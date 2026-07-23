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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            TimelineView(
                PushNotificationSentTimeTimelineSchedule(
                    sentTimes: store.notifications.compactMap(\.sentTime)
                )
            ) { context in
                VStack(alignment: .leading, spacing: 16) {
                    Text("새로운 알림")
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(.gray600)

                    LazyVStack(spacing: 32) {
                        ForEach(store.notifications) { notification in
                            notificationCell(notification, relativeTo: context.date)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    func notificationCell(_ notification: PushNotificationListItem, relativeTo referenceDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text(notification.title)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let sentTime = notification.sentTime {
                    Text(sentTime.relativeValue(to: referenceDate).displayText)
                        .nekiFont(.caption12Medium)
                        .foregroundStyle(.gray300)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            Text(notification.body)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}

#Preview {
    PushNotificationListCoordinatorView(
        store: Store(initialState: PushNotificationListFeature.State()) {
            PushNotificationListFeature()
        }
    )
}
