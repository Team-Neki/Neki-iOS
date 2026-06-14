//
//  AppCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture

struct AppCoordinatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var store: StoreOf<AppCoordinator>
    
    var body: some View {
        routeContent
            .task { await store.send(.onAppLaunched).finish() }
            .onChange(of: store.userSessionStatus) { _, newValue in
                store.send(.userSessionStatusChanged(newValue))
            }
            .onChange(of: scenePhase) { _, newValue in
                store.send(.scenePhaseChanged(newValue))
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRegisterAPNSToken)) { _ in
                store.send(.didRegisterAPNSToken)
            }
            .nekiToast(item: $store.toastItem)
            .modifier(VersionUpdateAlertModifier(store: store))
    }

    @ViewBuilder
    private var routeContent: some View {
        Group {
            switch store.route {
            case .splash:
                SplashView()
                
            case .onboarding:
                if let store = store.scope(state: \.route.onboarding, action: \.route.onboarding) {
                    OnboardingCoordinatorView(store: store)
                }
                
            case .auth:
                if let store = store.scope(state: \.route.auth, action: \.route.auth) {
                    LoginCoordinatorView(store: store)
                }
                
            case .mainTab:
                if let store = store.scope(state: \.route.mainTab, action: \.route.mainTab) {
                    MainTabCoordinatorView(store: store)
                }
            }
        }
    }
}


// MARK: - VersionUpdateAlertModifier

private struct VersionUpdateAlertModifier: ViewModifier {
    @Bindable var store: StoreOf<AppCoordinator>

    func body(content: Content) -> some View {
        let alert: AppCoordinator.VersionUpdateAlertType? = store.versionAlert

        content.nekiAlert(
            isPresented: $store.isAlertPresented,
            style: alert?.style ?? NekiAlertStyle.cancelable,
            contentStyle: .standard,
            title: alert?.title ?? "",
            subtitle: alert?.subtitle ?? "",
            confirmText: alert?.confirmText ?? "",
            cancelText: alert?.cancelText ?? nil,
            hasIcon: true,
            onConfirm: { store.send(.didTapUpdateAlert) },
            onCancel: { store.send(.didTapLaterAlert) }
        )
    }
}
