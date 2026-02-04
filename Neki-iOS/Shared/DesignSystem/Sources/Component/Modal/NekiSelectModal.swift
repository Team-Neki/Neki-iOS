//
//  NekiSelectModal.swift
//  Neki-iOS
//
//  Created by OneTen on 1/4/26.
//

import SwiftUI

struct NekiSelectContainer<Content: View>: View {
    let title: String?
    let onExit: () -> Void
    let content: Content
    
    init(
        title: String? = nil,
        onExit: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onExit = onExit
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let title = title {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .nekiFont(.title20SemiBold)
                        .foregroundStyle(.gray800)
                    
                    Spacer()
                    
                    Button {
                        onExit()
                    } label: {
                        Image(.iconXmarkBlack)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            
            content
                .padding(.top, title == nil ? 12 : 16)
                .padding(.bottom, title == nil ? 12 : 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

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
    
    let style: AlertStyle
    private let items: [InternalItem]
    let onSelect: (Int) -> Void
    
    public init(
        style: AlertStyle,
        items: [String]? = nil,
        onSelect: @escaping (Int) -> Void
    ) {
        self.style = style
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
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                Button {
                    onSelect(item.index)
                } label: {
                    rowView(for: item)
                }
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
