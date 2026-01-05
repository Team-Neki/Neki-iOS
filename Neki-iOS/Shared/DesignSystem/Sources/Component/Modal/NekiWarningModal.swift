//
//  NekiWarningModal.swift
//  Neki-iOS
//
//  Created by OneTen on 1/4/26.
//

import SwiftUI

public struct NekiWarningModal: View {
    
    // MARK: - Properties
    
    let titleMessage: String
    let onExit: () -> Void
    
    //MARK: - init

    public init(
        titleMessage: String,
        onExit: @escaping () -> Void
    ) {
        self.titleMessage = titleMessage
        self.onExit = onExit
    }
    
    // MARK: - Main Body

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Image(.iconCircleAlertFill)
                .padding(.top, 20)
            
            Text(titleMessage)
                .nekiFont(.body14Regular)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray500)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            Button(action: {
                onExit()
            }) {
                Image(.iconXmarkBlack)
                    .padding(12)
            }
            , alignment: .topTrailing
        )
    }
}
