//
//  NekiTabBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/18/26.
//

import SwiftUI

enum NekiTab: CaseIterable {
    case archive, pose, add, map, myPage
    
    var title: String {
        switch self {
        case .archive: return "아카이빙"
        case .pose: return "포즈"
        case .add: return "사진 추가"
        case .map: return "네컷지도"
        case .myPage: return "마이"
        }
    }
    
    func icon(isSelected: Bool) -> ImageResource {
        switch self {
        case .archive: return isSelected ? .iconTabArchiveFill : .iconTabArchive
        case .pose:    return isSelected ? .iconTabPoseFill    : .iconTabPose
        case .add:  return .iconTabAdd
        case .map:     return isSelected ? .iconTabMapFill     : .iconTabMap
        case .myPage:  return isSelected ? .iconTabMypageFill  : .iconTabMypage
        }
    }
}

struct NekiTabBar: View {
    @Binding var selectedTab: NekiTab
    
    let onAddTap: () -> Void
    
    var body: some View {
        HStack(spacing: .zero) {
            ForEach(NekiTab.allCases, id: \.self) { tab in
                Button {
                    guard case .add = tab else { return selectedTab = tab }
                    onAddTap()
                } label: {
                    VStack(alignment: .center, spacing: 2) {
                        ZStack {
                            if case .add = tab {
                                Color.clear.frame(width: 26, height: 26)
                                    .overlay {
                                        Image(tab.icon(isSelected: true))
                                            .offset(y: -10)
                                    }
                            } else {
                                Image(tab.icon(isSelected: selectedTab == tab))
                                    .frame(width: 26, height: 26)
                            }
                        }
                        
                        Text(tab.title)
                            .nekiFont(.caption12Medium)
                            .foregroundColor(selectedTab == tab ? .gray800 : .gray500)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(height: 52, alignment: .center)
        .background(.white)
        .shadow(color: .black.opacity(0.04), radius: 5, y: -2)
    }
}
