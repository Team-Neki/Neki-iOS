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
            Circle()
                .frame(width: 80, height: 80)
            
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
        VStack(spacing: 24) {
            Text("편리한 네키 이용을 위한\n필수 약관에 동의해주세요.")
                .nekiFont(.title24SemiBold)
                .foregroundStyle(.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            options
        }
    }
    
    // TODO: 선택상태 바뀔 때마다 애니메이션 튀는 현상 해결, 특히 체크마크 아이콘
    private var options: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.toggleAllAgreements)
            } label: {
                HStack(spacing: 10) {
                    Image(store.isAllAgreed ? .iconCheckmark : .iconCheckmarkGray)
                    
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
            
            VStack(alignment: .leading, spacing: .zero) {
                ForEach(TermsType.allCases) { type in
                    HStack(spacing: .zero) {
                        Button {
                            store.send(.toggleAgreement(type))
                        } label: {
                            HStack(spacing: 10) {
                                if let agreement = store.agreements[id: type] {
                                    Image(agreement.isAgreed ? .iconCheckmark : .iconCheckmarkGray)
                                    
                                    HStack {
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
                        
                        Link(destination: URL(string: "https://example.com")!) { // TODO: 노션 약관 페이지로 이동시키기
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
