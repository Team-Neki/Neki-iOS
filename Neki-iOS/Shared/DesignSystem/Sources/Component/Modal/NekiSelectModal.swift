//
//  NekiSelectModal.swift
//  Neki-iOS
//
//  Created by OneTen on 1/4/26.
//

import SwiftUI

public struct NekiSelectModal: View {
    
    public enum AlertStyle {
        case plain
        case map
    }
    
    public enum MapItem: Int, CaseIterable {
        case google = 0
        case naver
        case kakao
        
        var title: String {
            switch self {
            case .google: return "구글맵"
            case .naver: return "네이버 지도"
            case .kakao: return "카카오맵"
            }
        }
        
        var icon: UIImage {
            switch self {
            case .google: return .imgGooglemapModal
            case .naver: return .imgNavermapModal
            case .kakao: return .imgKakaomapModal
            }
        }
    }
    
    private struct InternalItem: Identifiable {
        let id = UUID()
        let index: Int
        let iconImage: UIImage?
        let text: String
    }
    
    // MARK: - Properties
    
    let style: AlertStyle
    private let items: [InternalItem]
    let onExit: () -> Void
    let onSelect: (Int) -> Void
    
    // MARK: - Init
    
    public init(
        style: AlertStyle,
        items: [String]? = nil,
        onExit: @escaping () -> Void,
        onSelect: @escaping (Int) -> Void
    ) {
        self.style = style
        self.onExit = onExit
        self.onSelect = onSelect
        
        if style == .map {
            self.items = MapItem.allCases.map { item in
                InternalItem(index: item.rawValue, iconImage: item.icon, text: item.title)
            }
        } else {
            self.items = (items ?? []).enumerated().map { index, text in
                InternalItem(index: index, iconImage: nil, text: text)
            }
        }
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if style == .map {
                mapHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onSelect(item.index)
                    } label: {
                        rowView(for: item)
                    }
                }
            }
            .padding(.bottom, style == .map ? 24 : 12)
            .padding(.top, style == .map ? 16 : 12)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
}


// MARK: - Sub Views

extension NekiSelectModal {
    @ViewBuilder
    private var mapHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("길찾기")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray800)
            
            Spacer()
            
            Button {
                onExit()
            } label: {
                Image(.iconXmarkBlack)
            }
        }
    }
    
    @ViewBuilder
    private func rowView(for item: InternalItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if style == .map {
                if let icon = item.iconImage {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                
                Text(item.text)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)
                
                Spacer()
            } else {
                Spacer()
                Text(item.text)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, style == .map ? 12 : 16)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        var body: some View {
            ZStack {
                Color.gray.opacity(0.5).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    
                    // 사용 예시 1: 지도 모달
                    NekiSelectModal(
                        style: .map,
                        onExit: { print("닫기") },
                        onSelect: { index in
                            if let mapItem = NekiSelectModal.MapItem(rawValue: index) {
                                switch mapItem {
                                case .google:
                                    print("구글맵 URL Scheme 실행")
                                case .naver:
                                    print("네이버 지도 URL Scheme 실행")
                                case .kakao:
                                    print("카카오맵 URL Scheme 실행")
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 30)
                    
                    // 사용 예시 2: 일반 선택 모달
                    NekiSelectModal(
                        style: .plain,
                        items: ["수정하기", "삭제하기"],
                        onExit: { print("닫기") },
                        onSelect: { index in
                            if index == 0 {
                                print("수정 화면으로 이동")
                            } else if index == 1 {
                                print("삭제 API 호출")
                            }
                        }
                    )
                    .padding(.horizontal, 30)
                }
            }
        }
    }
    
    return PreviewWrapper()
}
