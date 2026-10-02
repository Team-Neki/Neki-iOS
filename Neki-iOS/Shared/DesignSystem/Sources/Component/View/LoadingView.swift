//
//  LoadingView.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/16/26.
//

import SwiftUI

public struct LoadingView: View {
    private let message: String
    
    public init(message: String = "") {
        self.message = message
    }
    
    public var body: some View {
        ZStack {
            Color.gray900.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                NekiLoadingIndicator()
                
                Text(message)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.white)
            }
        }
        .presentationBackground(.clear)
    }
}
