//
//  PushNotificationConsentAlertPreview.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import SwiftUI

struct PushNotificationConsentAlertPreview: View {
    @State private var isPresented = true

    var body: some View {
        Color.gray25
            .ignoresSafeArea()
            .overlay {
                Button("알림 다시 보기") {
                    isPresented = true
                }
                .buttonStyle(.nekiCTA(.primary))
                .padding(.horizontal, 28)
            }
            .nekiAlert(
                isPresented: $isPresented,
                style: .cancelable,
                contentStyle: .marketingConsent(
                    description:
                        Text("마케팅 정보 푸시 수신 동의 여부는 ")
                            .foregroundColor(.gray400)
                        + Text("마이페이지 >\n권한 설정 > 알림 설정")
                            .foregroundColor(.primary500)
                        + Text("에서 변경 가능해요.")
                            .foregroundColor(.gray400)
                ),
                title: "놓치지 마세요!",
                subtitle: "네키의 이벤트, 혜택 프로모션,\n신규 업데이트 소식을 선별해서 알려드려요.",
                confirmText: "네, 알려주세요",
                cancelText: "괜찮아요",
                hasIcon: true,
                onConfirm: { isPresented = false },
                onCancel: { isPresented = false }
            )
    }
}

#Preview("마케팅 알림 수신 동의") {
    PushNotificationConsentAlertPreview()
}
