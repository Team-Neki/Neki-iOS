//
//  ArchiveAlbumEmptyView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI

struct ArchiveEmptyView: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Circle()
                .fill(.gray50)
                .frame(width: 104, height: 104)
            
            Text(description)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray300)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
