//
//  PhotoBoothSearchView.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/27/26.
//

import SwiftUI
import ComposableArchitecture

struct PhotoBoothSearchView: View {
    @Bindable var store: StoreOf<PhotoBoothSearchFeature>
    @FocusState private var isSearchFieldFocused: Bool

    private enum Metrics {
        static let searchFieldHorizontalPadding: CGFloat = 20
        static let searchFieldTopPadding: CGFloat = 8
        static let listTopPadding: CGFloat = 20
        static let cellSpacing: CGFloat = 12
        static let floatingButtonBottomPadding: CGFloat = 12
        /// 뒤에 이만큼의 셀이 남았을 때 다음 후보 페이지를 미리 부릅니다.
        static let prefetchDistance: Int = 5
    }

    var body: some View {
        VStack(spacing: .zero) {
            NekiSearchField(
                text: $store.searchText,
                state: searchFieldState,
                isFocused: $isSearchFieldFocused,
                prompt: "브랜드, 지점명, 지역을 검색해보세요",
                onBack: { withoutAnimation { store.send(.dismissSearch) } },
                onSubmit: {
                    isSearchFieldFocused = false
                    store.send(.submitSearch)
                }
            )
            .padding(.horizontal, Metrics.searchFieldHorizontalPadding)
            .padding(.top, Metrics.searchFieldTopPadding)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .safeAreaInset(edge: .bottom, spacing: .zero) {
            ChipFloatingButton(.map) { withoutAnimation { store.send(.dismissSearch) } }
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .padding(.bottom, Metrics.floatingButtonBottomPadding)
        }
        .nekiLoading(isPresented: store.isLoading, message: loadingMessage)
        // 앱 전역 토스트는 이 화면(전체 화면 표시) 아래에 그려져 보이지 않으므로 여기서 직접 띄웁니다.
        .nekiToast(item: $store.toast)
        // 지도에서 검색어를 눌러 다시 들어온 경우에는 결과를 가리지 않도록 키보드를 올리지 않습니다.
        .onAppear { isSearchFieldFocused = store.searchText.isEmpty }
    }
}


// MARK: - PhotoBoothSearchView + Subviews

private extension PhotoBoothSearchView {
    /// 검색 진행 상태에 따라 후보 목록 또는 안내 화면을 노출합니다.
    @ViewBuilder
    var content: some View {
        switch store.contentState {
        case .results:
            candidateList

        case .guide:
            messageView(
                inputImage: .iconPlace,
                title: "어디에서 네컷을 찍을까요?\n브랜드나 지점을 검색해보세요.",
                caption: "지역 상세 검색은 현재 서울만 지원하고 있어요."
            )

        case .noResult:
            messageView(
                inputImage: .iconNoResult,
                title: "조건에 맞는 포토부스가 없어요.\n다른 지역이나 브랜드로 검색해보세요.",
            )

        case .failure(.network):
            messageView(
                inputImage: .iconNetworkError,
                title: "네트워크 연결이 불안정해요\n잠시 후 다시 시도해주세요."
            )

        case .failure(.unknown):
            messageView(
                inputImage: .iconNetworkError,
                title: "일시적인 오류가 발생했어요\n잠시 후 다시 시도해주세요."
            )
        }
    }

    /// 지역 → 지하철역 → 포토부스 순서로 정렬된 검색 후보를 유형 구분 없이 한 목록으로 노출합니다.
    ///
    /// 앞선 유형을 모두 불러온 뒤 다음 유형으로 넘어가므로 새 후보는 항상 목록 끝에 이어집니다.
    var candidateList: some View {
        let keyword = store.query?.rawValue ?? ""
        let lastRowID = store.rows.last?.id
        // 마지막 셀에서 부르면 요청이 오가는 동안 목록이 바닥에서 멈추므로 몇 셀 앞에서 미리 부릅니다.
        // 목록이 임계값보다 짧으면 첫 셀이 곧 미리 부를 셀입니다.
        let prefetchRowID = store.rows.dropLast(Metrics.prefetchDistance).last?.id ?? store.rows.first?.id

        return ScrollView {
            LazyVStack(spacing: Metrics.cellSpacing) {
                ForEach(store.rows) { row in
                    PhotoBoothSearchCandidateCell(
                        candidate: row.candidate,
                        keyword: keyword,
                        distance: row.distance,
                        showsDivider: row.id != lastRowID
                    ) {
                        store.send(.didSelectCandidate(row.candidate))
                    }
                    .onAppear {
                        // 페이지가 붙으면 미리 부를 셀이 이미 화면에 떠 있을 수 있어 마지막 셀을 예비 트리거로 둡니다.
                        // 두 셀이 함께 나타나도 리듀서가 `isFetching`으로 걸러 요청은 한 번만 나갑니다.
                        guard row.id == prefetchRowID || row.id == lastRowID else { return }
                        store.send(.fetchNextCandidatePage)
                    }
                }
            }
            .padding(.top, Metrics.listTopPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }

    func messageView(inputImage: ImageResource = .iconPlace, title: String, caption: String? = nil) -> some View {
        VStack(spacing: 20) {
            Image(inputImage)

            VStack(spacing: 8) {
                Text(title)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray500)

                if let caption {
                    Text(caption)
                        .nekiFont(.caption11Medium)
                        .foregroundStyle(.gray300)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}


// MARK: - PhotoBoothSearchView + Policy

private extension PhotoBoothSearchView {
    /// 진행 중인 요청에 맞는 로딩 문구입니다.
    var loadingMessage: String {
        store.isFetchingSearchResult ? "포토부스를 불러오고 있어요." : "검색 결과를 불러오고 있어요."
    }

    /// 제출한 검색어가 필드에 남아 결과를 보고 있는 동안에만 검색 완료 형태로 표시합니다.
    ///
    /// 다시 입력을 시작하거나(포커스가 돌아오거나) 검색어를 비우면 입력 중 형태로 되돌아갑니다.
    /// 검색어를 비워도 결과는 그대로 두므로 필드 모양만 입력 중으로 되돌아갑니다.
    var searchFieldState: NekiSearchFieldState {
        let hasSubmittedKeyword = store.mode == .searching && store.searchText.isEmpty == false
        return isSearchFieldFocused || hasSubmittedKeyword == false ? .editing : .completed
    }
}

#Preview {
    PhotoBoothSearchView(
        store: .init(initialState: PhotoBoothSearchFeature.State()) { PhotoBoothSearchFeature() }
    )
}
