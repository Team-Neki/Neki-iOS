//
//  DeveloperDiagnosticsView.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import SwiftUI
import ComposableArchitecture

struct DeveloperDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<DeveloperDiagnosticsFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(store.diagnostics.sections) { section in
                    diagnosticsSection(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .nekiToolbar {
            NekiToolBar.back { dismiss() }
        } center: {
            NekiToolBar.textCenter("개발자 진단")
        } right: {
            Button {
                store.send(.refreshButtonTapped)
            } label: {
                Text(store.isLoading ? "갱신중" : "새로고침")
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.primary400)
            }
            .disabled(store.isLoading)
        }
        .task { await store.send(.onAppear).finish() }
    }
}


// MARK: - DeveloperDiagnosticsView + Subviews

private extension DeveloperDiagnosticsView {
    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("앱 진단 정보")
                .nekiFont(.title18SemiBold)
                .foregroundStyle(.gray900)

            Text("QA 중 앱 환경과 주요 런타임 상태를 확인하기 위한 내부 진단 정보입니다.")
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray500)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func diagnosticsSection(_ section: AppDiagnostics.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray400)

            VStack(spacing: .zero) {
                ForEach(section.rows) { row in
                    diagnosticsRow(row)
                }
            }
        }
    }

    func diagnosticsRow(_ row: AppDiagnostics.Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.title)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray400)

            Text(row.value)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray900)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.gray50)
                .frame(height: 1)
        }
    }
}

#Preview {
    DeveloperDiagnosticsView(
        store: .init(
            initialState: DeveloperDiagnosticsFeature.State(),
            reducer: { DeveloperDiagnosticsFeature() }
        )
    )
}
