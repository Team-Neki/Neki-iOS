//
//  NekiLoadingModifier.swift
//  Neki-iOS
//
//  Created by Codex on 8/4/26.
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

private struct NekiLoadingModifier: ViewModifier {
    let isPresented: Bool
    let message: String
    let policy: NekiLoadingPresentationPolicy

    @State private var isIndicatorVisible = false
    @State private var indicatorPresentedAt: ContinuousClock.Instant?

    private let clock = ContinuousClock()

    func body(content: Content) -> some View {
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
            .task(id: isPresented) { await updateIndicatorVisibility() }
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
    func nekiLoading(
        isPresented: Bool,
        message: String = "",
        policy: NekiLoadingPresentationPolicy = .standard
    ) -> some View {
        modifier(NekiLoadingModifier(
            isPresented: isPresented,
            message: message,
            policy: policy
        ))
    }
}
