//
//  TermsAgreementView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import SwiftUI
import ComposableArchitecture

public struct TermsAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var store: StoreOf<TermsAgreementFeature>
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(.iconGpicAgreement)
            
            terms
            
            Spacer()
            
            Button {
                store.send(.didFinishOnboarding)
            } label: {
                Text("다음으로")
            }
            .buttonStyle(.nekiCTA())
            .disabled(store.isConfirmButtonEnabled == false)
        }
        .padding()
        .nekiToolbar {
            NekiToolBar.back { dismiss() }
        } center: {
            NekiToolBar.textCenter("이용약관")
        }
    }
    
    private var terms: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("편리한 네키 이용을 위한\n필수 약관에 동의해주세요.")
                .nekiFont(.title24SemiBold)
                .foregroundStyle(.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            options
        }
    }
    
    private var options: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.send(.toggleAllAgreements)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(store.isAllAgreed ? .iconCheckmark : .iconCheckmarkGray)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("약관 전체 동의")
                        .nekiFont(.title18SemiBold)
                        .foregroundStyle(.gray900)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.gray100)
                        .background(.gray25)
                )
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(TermsType.allCases) { type in
                    HStack(alignment: .center, spacing: 0) {
                        Button {
                            store.send(.toggleAgreement(type))
                        } label: {
                            HStack(spacing: 10) {
                                if let agreement = store.agreements[id: type] {
                                    Image(agreement.isAgreed ? .iconCheckmark : .iconCheckmarkGray)
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    
                                    HStack(alignment: .center, spacing: 0) {
                                        Text(agreement.isRequired ? "(필수)" : "(선택)")
                                            .nekiFont(.body14Medium)
                                            .foregroundStyle(.gray500)
                                        
                                        Text(type.displayName)
                                            .nekiFont(.body16Medium)
                                            .foregroundStyle(.gray900)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical)
                                    }
                                }
                            }
                        }
                        
                        Button {
                            store.send(.termPageLinkTapped(type))
                        } label: {
                            Image(.iconChevronRight)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TermsAgreementView(store: .init(initialState: TermsAgreementFeature.State(), reducer: { TermsAgreementFeature() }))
}
