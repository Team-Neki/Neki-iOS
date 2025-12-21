<h1 align="center">📸 우리만의 사진 저장소, 네키</h1>

<img width="2069" height="1479" alt="image 73" src="https://github.com/user-attachments/assets/33c8fdaa-559e-4d0f-a351-ea71cead6868" />


## Foldering

```Text

📁 Neki-iOS
├── 📁 APP
│   └── 📁 Sources
│       ├── 📁 Application
│       │   └── 📃 Neki_iOSApp.swift
│       └── 📁 Resources
├── 📁 Core
│   └── 📁 Sources
│       ├── 📁 Coordinator
│       │   └── 📁 Sources
│       ├── 📁 Logger
│       │   └── 📁 Sources
│       └── 📁 Network
│           └── 📁 Sources
├── 📁 Features
│   ├── 📁 Archive
│   │   └── 📁 Sources
│   │       ├── 📁 Data
│   │       │   └── 📁 Sources
│   │       ├── 📁 Domain
│   │       │   └── 📁 Sources
│   │       └── 📁 Presentation
│   │           └── 📁 Sources
│   │               └── 📁 Feature
│   │               └── 📁 View
│   └── 📁 Map
│       └── 📁 Sources
│           ├── 📁 Data
│           │   └── 📁 Sources
│           ├── 📁 Domain
│           │   └── 📁 Sources
│           └── 📁 Presentation
│               └── 📁 Sources
│                   └── 📁 Feature
│                   └── 📁 View
└── 📁 Shared
    └── 📁 DesignSystem
        ├── 📁 Resources
        │   └── 📃 Assets.xcassets
        └── 📁 Sources

```

## Convention

### Coding

[Swift 스타일쉐어 가이드](https://github.com/StyleShare/swift-style-guide)를 기반으로

팀원의 기존 스타일을 반영하였습니다.

### Commit

```markdown
[Feat] : 새로운 기능 구현
[Fix] : 버그, 오류 해결
[Chore] : 코드 수정, 내부 파일 수정, 애매한 것들이나 잡일은 이걸로!
[Add] : 라이브러리 추가, 에셋 추가
[Del] : 쓸모없는 코드 삭제
[Docs] : README나 WIKI 등의 문서 개정
[Refactor] : 전면 수정이 있을 때 사용합니다.
[Setting] : 프로젝트 설정관련이 있을 때 사용합니다.
[Merge] : Pull Develop
```

예시 [Feat] #1 - 메인 UI 구현
