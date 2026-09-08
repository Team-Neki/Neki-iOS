//
//  NekiSearchField.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/27/26.
//

import SwiftUI

/// 검색 필드의 상태입니다.
///
/// - Note: `State`가 아닌 최상위 타입인 이유는 `NekiSearchField` 안에 중첩하면
///   SwiftUI의 `@State`를 가리기 때문입니다.
public enum NekiSearchFieldState: Equatable {
    /// 검색 화면으로 이동하기 위한 진입점입니다. 입력할 수 없고 탭하면 이동합니다.
    case idle
    /// 검색어를 입력하는 중입니다. 테두리를 노출하고 입력한 검색어를 Medium으로 표시합니다.
    case editing
    /// 검색을 완료한 상태입니다. 그림자와 지우기 버튼을 노출하고 검색어를 SemiBold로 표시합니다.
    case completed
}

/// 캡슐형 검색 필드입니다.
///
/// `state`에 따라 좌측 아이콘, 테두리와 그림자, 검색어 서체, 지우기 버튼 노출이 달라집니다.
/// 입력 없이 검색 화면으로 이동하기만 하는 진입점에는 ``NekiSearchField/entry(_:action:)``을,
/// 검색 화면 밖에서 완료한 검색어만 보여 주는 자리에는 ``NekiSearchField/completed(_:onEdit:onClear:)``을 사용합니다.
public struct NekiSearchField: View {
    @Binding private var text: String

    private let state: NekiSearchFieldState
    private let prompt: String
    private let isFocused: FocusState<Bool>.Binding?
    /// 검색어를 이 필드에서 직접 고칠 수 있는지 여부입니다.
    ///
    /// 검색 화면 밖에서는 검색어를 보여 주기만 하므로 텍스트 필드 대신 문자열을 그립니다.
    private let isEditable: Bool
    private let onBack: (() -> Void)?
    private let onSubmit: (() -> Void)?
    private let onTap: (() -> Void)?
    private let onClear: (() -> Void)?

    private init(
        text: Binding<String>,
        state: NekiSearchFieldState,
        isFocused: FocusState<Bool>.Binding?,
        isEditable: Bool,
        prompt: String,
        onBack: (() -> Void)?,
        onSubmit: (() -> Void)?,
        onTap: (() -> Void)?,
        onClear: (() -> Void)?
    ) {
        self._text = text
        self.state = state
        self.isFocused = isFocused
        self.isEditable = isEditable
        self.prompt = prompt
        self.onBack = onBack
        self.onSubmit = onSubmit
        self.onTap = onTap
        self.onClear = onClear
    }

    /// 검색어를 입력받는 검색 필드를 생성합니다.
    ///
    /// - Parameters:
    ///   - text: 사용자가 입력 중인 검색어
    ///   - state: 검색 필드의 상태. `.editing` 또는 `.completed`를 전달합니다.
    ///   - isFocused: 입력 포커스를 제어할 바인딩
    ///   - prompt: 검색어가 비어 있을 때 표시할 안내 문구
    ///   - onBack: 좌측 뒤로가기 버튼을 눌렀을 때 실행할 동작
    ///   - onSubmit: 키보드 검색 또는 우측 검색 버튼으로 검색어를 제출했을 때 실행할 동작
    public init(
        text: Binding<String>,
        state: NekiSearchFieldState,
        isFocused: FocusState<Bool>.Binding,
        prompt: String,
        onBack: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.init(
            text: text,
            state: state,
            isFocused: isFocused,
            isEditable: true,
            prompt: prompt,
            onBack: onBack,
            onSubmit: onSubmit,
            onTap: nil,
            onClear: nil
        )
    }

    /// 검색 화면으로 이동하기 위한 진입점 검색 필드를 생성합니다.
    ///
    /// 입력 기능이 없으므로 검색어와 포커스를 받지 않습니다.
    ///
    /// - Parameters:
    ///   - prompt: 검색어 자리에 표시할 안내 문구
    ///   - action: 필드를 눌렀을 때 실행할 동작
    public static func entry(_ prompt: String, action: @escaping () -> Void) -> NekiSearchField {
        NekiSearchField(
            text: .constant(""),
            state: .idle,
            isFocused: nil,
            isEditable: false,
            prompt: prompt,
            onBack: nil,
            onSubmit: nil,
            onTap: action,
            onClear: nil
        )
    }

    /// 검색을 완료한 검색어를 노출하는 검색 필드를 생성합니다.
    ///
    /// 입력은 검색 화면에서 하고 결과 화면에서는 검색어만 보여 주는 자리에 사용합니다.
    /// 검색어를 여기서 고치지 않으므로 검색어를 바인딩이 아닌 값으로 받고 포커스를 받지 않습니다.
    /// 뒤로가기·검색어·검색 버튼은 모두 검색어를 다시 입력하러 가는 하나의 동작으로 이어집니다.
    ///
    /// - Parameters:
    ///   - keyword: 검색을 완료한 검색어
    ///   - onEdit: 검색어를 다시 입력하러 갈 때 실행할 동작
    ///   - onClear: 우측 지우기 버튼으로 검색을 끝낼 때 실행할 동작
    public static func completed(
        _ keyword: String,
        onEdit: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> NekiSearchField {
        NekiSearchField(
            text: .constant(keyword),
            state: .completed,
            isFocused: nil,
            isEditable: false,
            prompt: "",
            onBack: onEdit,
            onSubmit: onEdit,
            onTap: onEdit,
            onClear: onClear
        )
    }

    public var body: some View {
        if state == .idle {
            Button { onTap?() } label: { field }
                .buttonStyle(.plain)
        } else {
            field
        }
    }
}


// MARK: - NekiSearchField + Subviews

private extension NekiSearchField {
    var field: some View {
        HStack(spacing: Metrics.spacing) {
            leading

            input

            if state != .idle {
                icon(.iconSearch) { onSubmit?() }
            } else {
                iconImage(.iconSearch)
            }

            if state == .completed {
                icon(.iconXmarkBlack, action: onClear ?? clear)
            }
        }
        .searchFieldContainer(state.decoration)
    }

    /// 진입점에서는 서비스 심볼을, 검색 화면에서는 뒤로가기 버튼을 노출합니다.
    @ViewBuilder
    var leading: some View {
        if state == .idle {
            iconImage(.iconNeki)
        } else {
            icon(.iconChevronLeft) { onBack?() }
        }
    }

    /// 진입점에서는 안내 문구를, 검색 화면에서는 편집 가능한 텍스트 필드를 노출합니다.
    ///
    /// 검색 화면 밖에서 결과를 보여 주는 동안에는 누르면 검색 화면으로 돌아가는 검색어를 노출합니다.
    ///
    /// - Note: 검색 화면에서는 검색을 완료한 뒤에도 텍스트 필드를 계층에 그대로 둡니다.
    ///   텍스트로 바꿔 끼우면 포커스를 받을 뷰가 사라져 `isFocused`에 `true`를 써도 무시되고,
    ///   필드를 눌러도 키보드가 다시 올라오지 않습니다.
    @ViewBuilder
    var input: some View {
        if state == .idle {
            label(prompt, font: .body16Medium, color: .gray800)
        } else if isEditable {
            textField
        } else {
            Button { onTap?() } label: {
                label(text, font: .body16SemiBold, color: .gray900)
            }
            .buttonStyle(.plain)
        }
    }

    /// 검색을 완료한 상태에서는 입력 중보다 굵고 진하게 표시합니다.
    @ViewBuilder
    var textField: some View {
        let field = TextField(
            "",
            text: $text,
            prompt: Text(prompt).foregroundStyle(.gray300)
        )
        .nekiFont(state == .completed ? .body16SemiBold : .body16Medium)
        .foregroundStyle(state == .completed ? .gray900 : .gray800)
        .submitLabel(.search)
        .onSubmit { onSubmit?() }

        if let isFocused {
            field.focused(isFocused)
        } else {
            field
        }
    }

    func label(_ text: String, font: FontStyle, color: Color) -> some View {
        Text(text)
            .nekiFont(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func iconImage(_ icon: ImageResource) -> some View {
        Image(icon)
            .resizable()
            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
    }

    func icon(_ icon: ImageResource, action: @escaping () -> Void) -> some View {
        Button(action: action) { iconImage(icon) }
            .buttonStyle(.plain)
    }

    /// 검색어를 지우고 다시 입력할 수 있도록 포커스를 되돌립니다.
    func clear() {
        text = ""
        isFocused?.wrappedValue = true
    }

    enum Metrics {
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let shadowRadius: CGFloat = 4
        static let shadowOffsetY: CGFloat = 2
    }
}


// MARK: - Shared Container

/// 검색 필드가 상태별로 사용하는 테두리/그림자 표현입니다.
private enum SearchFieldDecoration {
    /// 입력 중에 사용하는 테두리입니다.
    case border
    /// 진입점과 검색 완료에서 사용하는 그림자입니다.
    case shadow
}

private extension NekiSearchFieldState {
    var decoration: SearchFieldDecoration {
        switch self {
        case .editing: .border
        case .idle, .completed: .shadow
        }
    }
}

/// 검색 필드가 상태와 무관하게 공유하는 형태(여백, 배경, 모서리, 테두리/그림자)입니다.
private struct SearchFieldContainer: ViewModifier {
    let decoration: SearchFieldDecoration

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, NekiSearchField.Metrics.horizontalPadding)
            .padding(.vertical, NekiSearchField.Metrics.verticalPadding)
            .background(.white)
            .clipShape(.capsule)
            .overlay {
                if case .border = decoration {
                    Capsule().strokeBorder(.gray100)
                }
            }
            .shadow(
                color: decoration == .shadow ? .black.opacity(0.25) : .clear,
                radius: NekiSearchField.Metrics.shadowRadius,
                y: NekiSearchField.Metrics.shadowOffsetY
            )
    }
}

private extension View {
    func searchFieldContainer(_ decoration: SearchFieldDecoration) -> some View {
        modifier(SearchFieldContainer(decoration: decoration))
    }
}
