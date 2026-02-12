//
//  NekiTabBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/18/26.
//

import SwiftUI

enum NekiTab: CaseIterable {
    case archive, pose, qrScan, map, myPage
    
    var title: String {
        switch self {
        case .archive: return "아카이빙"
        case .pose: return "포즈"
        case .qrScan: return ""
        case .map: return "네컷지도"
        case .myPage: return "마이"
        }
    }
    
    func icon(isSelected: Bool) -> ImageResource {
        switch self {
        case .archive: return isSelected ? .iconTabArchiveFill : .iconTabArchive
        case .pose:    return isSelected ? .iconTabPoseFill    : .iconTabPose
        case .qrScan:  return .iconTabQrScan
        case .map:     return isSelected ? .iconTabMapFill     : .iconTabMap
        case .myPage:  return isSelected ? .iconTabMypageFill  : .iconTabMypage
        }
    }
}

struct NekiTabBar: View {
    @Binding var selectedTab: NekiTab
    
    let onQRScanTap: () -> Void
    
    var body: some View {
        HStack {
            ForEach(NekiTab.allCases, id: \.self) { tab in
                Button {
                    guard case .qrScan = tab else { return selectedTab = tab }
                    onQRScanTap()
                } label: {
                    if case .qrScan = tab {
                        Image(tab.icon(isSelected: selectedTab == tab))
                            .padding(7)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.primary300, .primary500],
                                            startPoint: .topTrailing,
                                            endPoint: .bottomLeading
                                        )
                                    )
                                    .shadow(color: .gray100, radius: 2, y: 4)
                            )
                            .offset(y: -14)
                    } else {
                        VStack(alignment: .center, spacing: 4) {
                            Image(tab.icon(isSelected: selectedTab == tab))
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
        }
        .background(.white)
    }
}
