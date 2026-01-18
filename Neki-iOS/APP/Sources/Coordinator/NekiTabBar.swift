//
//  NekiTabBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/18/26.
//

import SwiftUI

enum NekiTab: CaseIterable, Hashable {
    case pose, archive, map, mypage
    
    var title: String {
        switch self {
        case .archive:
            return "아카이빙"
        case .pose:
            return "포즈"
        case .map:
            return "네컷지도"
        case .mypage:
            return "마이"
        }
    }
    
    var defaultIcon: UIImage {
        switch self {
        case .archive:
            return .iconTabArchive
        case .pose:
            return .iconTabPose
        case .map:
            return .iconTabMap
        case .mypage:
            return .iconTabMypage
        }
    }
    
    var selectedIcon: UIImage {
        switch self {
        case .archive:
            return .iconTabArchiveFill
        case .pose:
            return .iconTabPoseFill
        case .map:
            return .iconTabMapFill
        case .mypage:
            return .iconTabMypageFill
        }
    }
}

struct NekiTabBar: View {
    @Binding var selectedTab: NekiTab
    
    var body: some View {
        HStack {
            ForEach(NekiTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(alignment: .center, spacing: 1) {
                        Image(uiImage: selectedTab == tab ? tab.selectedIcon : tab.defaultIcon)
                        Text(tab.title)
                            .nekiFont(.caption11Medium)
                            .foregroundColor(selectedTab == tab ? .gray800 : .gray500)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 52)
        .background(.white)
        
    }
}
