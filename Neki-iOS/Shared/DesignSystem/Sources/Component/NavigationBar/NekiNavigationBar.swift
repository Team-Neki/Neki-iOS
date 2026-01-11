//
//  NekiNavigationBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/10/26.
//

import SwiftUI

public struct NekiNavigationBar: View {
    
    // MARK: - Enums
    
    public enum LeftItem {
        case none
        case back(action: () -> Void)
        case close(action: () -> Void)
        case text(String, action: (() -> Void)?)
        case icon(UIImage, action: (() -> Void)?)
    }
    
    public enum CenterItem {
        case none
        case text(String)
    }
    
    public enum RightItem {
        case none
        case text(String, action: () -> Void)
        case icon(UIImage, action: () -> Void)
        case both([RightItem])
    }
    
    // MARK: - Properties
    
    let leftItem: LeftItem
    let centerItem: CenterItem
    let rightItem: RightItem
    
    // MARK: - init
    
    public init(leftItem: LeftItem, centerItem: CenterItem, rightItem: RightItem) {
        self.leftItem = leftItem
        self.centerItem = centerItem
        self.rightItem = rightItem
    }
        
    // MARK: - Body
    
    public var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 0) {
                leftView
                Spacer()
                rightView
            }
            .frame(height: 54)
            .padding(.horizontal, 20)
            
            centerView
        }
        .background(.white)
        .frame(height: 54)
    }
    
}


// MARK: - Subviews

private extension NekiNavigationBar {
    @ViewBuilder
    var leftView: some View {
        switch leftItem {
        case .none:
            EmptyView()
        case .back(let action):
            Button(action: action) {
                Image(.iconChevronLeft)
            }
        case .close(let action):
            Button(action: action) {
                Image(.iconXmarkBlack)
            }
        case .text(let title, let action):
            Button {
                if let action = action {
                    action()
                }
            } label: {
                Text(title)
                    .nekiFont(.title18SemiBold)
                    .foregroundStyle(.gray900)
            }
        case .icon(let image, let action):
            Button {
                if let action = action {
                    action()
                }
            } label: {
                Image(uiImage: image)
            }
        }
    }
    
    @ViewBuilder
    var centerView: some View {
        switch centerItem {
        case .none:
            EmptyView()
        case .text(let title):
            Text(title)
                .nekiFont(.title18SemiBold)
                .foregroundStyle(.gray900)
        }
    }
    
    @ViewBuilder
    var rightView: some View {
        switch rightItem {
        case .none:
            EmptyView()
            
        case .text(let title, let action):
            Button(action: action) {
                Text(title)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.primary500)
            }
            
        case .icon(let image, let action):
            Button(action: action) {
                Image(uiImage: image)
            }
            
        case .both(let items):
            HStack(alignment: .center, spacing: 12) {
                ForEach(0..<items.count, id: \.self) { index in
                    makeRightItem(items[index])
                }
            }
        }
    }
    
    @ViewBuilder
    func makeRightItem(_ item: RightItem) -> some View {
        switch item {
        case .text(let title, let action):
            Button(action: action) {
                Text(title)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.primary500)
            }
        case .icon(let image, let action):
            Button(action: action) {
                Image(uiImage: image)
            }
        default:
            EmptyView()
        }
    }
}

