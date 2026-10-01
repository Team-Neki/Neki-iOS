//
//  NekiLoadingModifier.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/4/26.
//

import SwiftUI

public struct NekiLoadingPresentationPolicy: Sendable {
    public let delay: Duration
    public let minimumVisibleDuration: Duration

    public init(
        delay: Duration,
        minimumVisibleDuration: Duration
    ) {
        self.delay = delay
        self.minimumVisibleDuration = minimumVisibleDuration
    }

    public static let standard = Self(
        delay: .milliseconds(250),
        minimumVisibleDuration: .milliseconds(400)
    )
}

/// 로딩을 어떤 모습으로 노출할지입니다.
public enum NekiLoadingStyle: Sendable {
    /// 화면 전체를 딤으로 덮고 인디케이터를 노출합니다. 문구를 넘기면 인디케이터 아래에 함께 노출합니다.
    ///
    /// 로딩이 끝날 때까지 입력을 막습니다.
    case fullScreen
    /// 딤과 문구 없이 본문 자리에 인디케이터만 노출합니다.
    ///
    /// 로딩 동안 본문은 터치를 받지 않고, 인디케이터가 떠 있는 동안에는 감춰집니다. 본문 바깥의 입력은 막지 않습니다.
    /// 다만 표시를 미루는 동안 VoiceOver로는 본문을 활성화할 수 있으므로, 로딩 중에 받으면 안 되는 동작은 리듀서에서 거릅니다.
    /// 표시를 미루는 동안에는 본문을 그대로 보여 주므로, 새 내용이 준비될 때까지 직전 본문을 유지하는 자리에 겁니다.
    /// 로딩과 함께 본문이 비는 자리에 걸면 표시를 미루는 동안 빈 본문이 보였다가 사라집니다.
    case inline
}

private struct NekiLoadingModifier: ViewModifier {
    let isPresented: Bool
    let message: String
    let style: NekiLoadingStyle
    let policy: NekiLoadingPresentationPolicy

    @State private var isIndicatorVisible = false
    @State private var indicatorPresentedAt: ContinuousClock.Instant?

    private let clock = ContinuousClock()

    func body(content: Content) -> some View {
        styledContent(content)
            .task(id: isPresented) { await updateIndicatorVisibility() }
    }

    @ViewBuilder
    private func styledContent(_ content: Content) -> some View {
        switch style {
        case .fullScreen:
            fullScreenContent(content)

        case .inline:
            inlineContent(content)
        }
    }

    private func fullScreenContent(_ content: Content) -> some View {
        content
            .allowsHitTesting(isPresented == false && isIndicatorVisible == false)
            .disabled(isPresented || isIndicatorVisible)
            .overlay {
                if isPresented || isIndicatorVisible {
                    ZStack {
                        if isPresented {
                            Color.clear
                                .ignoresSafeArea()
                        }

                        if isIndicatorVisible { LoadingView(message: message) }
                    }
                }
            }
    }

    private func inlineContent(_ content: Content) -> some View {
        // 인디케이터를 최소 노출 시간만큼 붙잡아 두는 동안에는 작업이 이미 끝나 본문이 결과로 바뀌어 있습니다.
        // 결과가 인디케이터 뒤로 비치지 않도록 본문을 감춰 두었다가 인디케이터가 내려갈 때 함께 드러냅니다.
        // 표시를 미루는 동안 보이는 본문은 터치만 막습니다. `disabled`는 버튼을 흐리게 그려,
        // 로딩이 빨리 끝나도 본문이 흐려졌다 돌아오는 깜빡임이 생깁니다.
        content
            .opacity(isIndicatorVisible ? 0 : 1)
            .allowsHitTesting(isPresented == false && isIndicatorVisible == false)
            .overlay {
                if isIndicatorVisible { NekiLoadingIndicator() }
            }
    }

    @MainActor
    private func updateIndicatorVisibility() async {
        if isPresented {
            guard isIndicatorVisible == false else { return }
            do { try await clock.sleep(for: policy.delay) } catch { return }
            guard Task.isCancelled == false else { return }
            indicatorPresentedAt = clock.now
            isIndicatorVisible = true
            return
        }

        guard isIndicatorVisible else { return }
        if let indicatorPresentedAt {
            let elapsed = indicatorPresentedAt.duration(to: clock.now)
            let remainingDuration = policy.minimumVisibleDuration - elapsed
            if remainingDuration > .zero {
                do { try await clock.sleep(for: remainingDuration) } catch { return }
            }
        }
        guard Task.isCancelled == false else { return }
        isIndicatorVisible = false
        indicatorPresentedAt = nil
    }
}

public extension View {
    /// 로딩을 노출합니다. 표시 정책은 모습과 상관없이 같습니다.
    ///
    /// - Parameters:
    ///   - isPresented: 로딩 중인지 여부입니다.
    ///   - style: 로딩을 노출할 모습입니다. 기본값은 화면 전체를 덮는 ``NekiLoadingStyle/fullScreen``입니다.
    ///   - message: 인디케이터 아래에 노출할 문구입니다. ``NekiLoadingStyle/fullScreen``에서만 씁니다.
    ///   - policy: 인디케이터 표시 정책입니다.
    func nekiLoading(
        isPresented: Bool,
        style: NekiLoadingStyle = .fullScreen,
        message: String = "",
        policy: NekiLoadingPresentationPolicy = .standard
    ) -> some View {
        modifier(NekiLoadingModifier(
            isPresented: isPresented,
            message: message,
            style: style,
            policy: policy
        ))
    }
}
