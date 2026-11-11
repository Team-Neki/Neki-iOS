//
//  NotificationGuideModalModifier.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import ComposableArchitecture
import SwiftUI

/// 알림 안내 모달입니다. 바깥을 누르면 "다음에 하기"와 같고, 처리 중에는 버튼과 바깥 누름을 막습니다.
struct NotificationGuideModalModifier: ViewModifier {
    let store: StoreOf<NotificationGuideFeature>

    /// 모달이 닫히는 동안 문구가 비지 않도록 마지막에 띄운 모달을 남겨 둡니다.
    @State private var displayedModal: NotificationGuideModal?

    func body(content: Content) -> some View {
        let modal = store.modal ?? displayedModal

        content
            .nekiAlert(
                isPresented: Binding(
                    get: { store.modal != nil },
                    set: { _ in }
                ),
                style: .cancelable,
                title: modal?.title ?? "",
                subtitle: modal?.message ?? "",
                confirmText: modal?.confirmButtonTitle ?? "",
                cancelText: NotificationGuideModal.cancelButtonTitle,
                isProcessing: store.isProcessing,
                hasIcon: true,
                icon: .bell,
                onConfirm: { store.send(.confirmButtonTapped) },
                onCancel: { store.send(.cancelButtonTapped) }
            )
            .onChange(of: store.modal) { _, newModal in
                guard let newModal else { return }
                displayedModal = newModal
            }
    }
}
