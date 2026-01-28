//
//  NekiTabBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/18/26.
//

import SwiftUI

enum NekiTab: CaseIterable {
    case archive, pose, map, myPage
    
    var title: String {
        switch self {
        case .archive:
            return "아카이빙"
        case .pose:
            return "포즈"
        case .map:
            return "네컷지도"
        case .myPage:
            return "마이"
        }
    }
    
    func icon(isSelected: Bool) -> UIImage {
        switch self {
        case .archive: return isSelected ? .iconTabArchiveFill : .iconTabArchive
        case .pose:    return isSelected ? .iconTabPoseFill    : .iconTabPose
        case .map:     return isSelected ? .iconTabMapFill     : .iconTabMap
        case .myPage:  return isSelected ? .iconTabMypageFill  : .iconTabMypage
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
                    VStack(alignment: .center, spacing: 4) {
                        Image(uiImage: tab.icon(isSelected: selectedTab == tab))
                            .resizable()
                            .frame(width: 26, height: 26)
                        
                        Text(tab.title)
                            .nekiFont(.caption12Medium)
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

#Preview {
    NekiTabBar(selectedTab: .constant(.map))
}
