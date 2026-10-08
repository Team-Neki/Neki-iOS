//
//  MapSearchField.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/30/26.
//

import SwiftUI
import ComposableArchitecture

/// 지도 상단의 검색 필드입니다.
///
/// 검색 결과를 보는 동안에는 검색어를 검색 완료 형태로 남겨 둡니다.
/// 검색어를 누르면 그 검색어로 검색 화면에 다시 들어가고, 지우기 버튼은 검색을 끝냅니다.
///
/// 검색어에 따라 형태를 고르는 일은 지도 화면이 아니라 이 뷰가 맡습니다.
struct MapSearchField: View {
    let store: StoreOf<MapFeature>

    var body: some View {
        field
    }

    /// 검색 결과를 보고 있으면 검색 완료 형태를, 아니면 진입점을 고릅니다.
    ///
    /// - Note: 두 형태는 뷰를 분기하지 않고 값으로 고릅니다.
    ///   검색 필드는 시트 단계·부스 선택 애니메이션 아래에 있어서, 분기로 나누면 검색 결과를 고르거나 지우면서
    ///   시트나 부스 선택이 함께 바뀔 때 두 캡슐이 겹쳐 크로스페이드됩니다. 값으로 고르면 캡슐은 그대로 두고 바뀐 내용만 갱신됩니다.
    private var field: NekiSearchField {
        if let keyword = store.appliedSearchQuery?.rawValue {
            .completed(
                keyword,
                onEdit: { store.send(.didTapSearchField) },
                onClear: { store.send(.didTapClearSearchButton) }
            )
        } else {
            .entry("네컷 부스 검색하기") { store.send(.didTapSearchField) }
        }
    }
}
