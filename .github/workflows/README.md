# iOS Deployment Automation

## Deployment units

개발기와 상용기는 서로 독립적인 앱과 버전 이력을 가집니다.

| Target | Scheme | Configuration | Bundle ID | Distribution |
| --- | --- | --- | --- | --- |
| `development` | `Neki-iOS.Dev` | `Staging` | `com.OneTen.Neki-iOS-dev` | TestFlight |
| `production` | `Neki-iOS` | `Release` | `com.OneTen.Neki-iOS` | TestFlight, App Store Review |

Apple Developer Team ID는 `P85DW78LYM`이며 Fastlane의 `deployment_configuration.rb`에서 관리합니다.

## Local Ruby environment

Fastlane은 Swift Package가 아닌 Ruby CLI이며 `Gemfile.lock`으로 버전을 고정합니다. 전역 Ruby와 gem을 오염시키지 않도록 mise 기반의 프로젝트 전용 Ruby 환경을 사용합니다.

```shell
mise install
mise exec -- bundle install
mise exec -- bundle exec fastlane --version
```

`.mise.toml`은 CI와 동일한 Ruby `3.3.12`를 사용하고 gem을 `.bundle/vendor`에 격리합니다. Fastlane 명령은 항상 `mise exec -- bundle exec fastlane ...` 형식으로 실행합니다.

## GitHub environments

Repository Settings의 Environments에 `development`와 `production`을 생성합니다. 상용 배포 전에 승인이 필요하다면 `production` Environment에 Required reviewers를 설정합니다.

각 Environment에는 다음 Secret을 같은 이름으로 등록합니다.

| Secret | Purpose |
| --- | --- |
| `BUILD_XCCONFIG` | Base64로 인코딩한 환경별 xcconfig |
| `FIREBASE_PLIST` | Base64로 인코딩한 환경별 Firebase plist |
| `APP_VERSION_API_ADDRESS` | 환경별 iOS 버전 조회 및 수정 API 전체 주소 |

다음 Secret은 Repository 공통으로 관리합니다.

| Secret | Purpose |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID |
| `ASC_KEY_CONTENT` | Base64로 인코딩한 App Store Connect API private key |
| `MATCH_GITHUB_CLIENT_ID` | Match 저장소 읽기용 GitHub App Client ID |
| `MATCH_GITHUB_APP_PRIVATE_KEY` | Match 저장소 읽기용 GitHub App private key |
| `MATCH_PASSWORD` | Match 저장소 암호화 비밀번호 |
| `DISCORD_WEBHOOK_URL` | 배포 결과 알림 Webhook |

App Store Connect API Key는 현재 Team에 속하고 두 앱에 접근할 수 있어야 합니다. Key를 교체하면 `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`를 같은 Key 세트로 함께 갱신합니다.

GitHub App은 `Team-Neki/Neki-fastlane-match-repo`에만 설치하고 Repository Contents 읽기 권한만 부여합니다. 워크플로는 실행 시점에 1시간 이내로 유효한 Installation Token을 생성하며 Job 종료 시 폐기합니다. Match 저장소에는 개발기와 상용기 앱 및 Share Extension의 App Store 프로파일이 모두 포함되어야 합니다.

현재 Team의 서명 자산은 Match 저장소의 `team-P85DW78LYM` 브랜치에서 관리합니다. 해당 브랜치에는 Apple Distribution identity 1개와 개발기·상용기 앱 및 Share Extension용 App Store 프로파일 4개가 포함되어 있으며, Fastlane readonly 동기화로 검증됐습니다. 기존 `release` 브랜치는 이전 자산 보존 용도로만 두고 CI에서 사용하지 않습니다.

## Version policy

배포 버전은 `MAJOR.MINOR.PATCH` 형식으로 직접 입력합니다. Fastlane은 입력 버전을 Archive의 `MARKETING_VERSION`으로 사용하고 App Store Connect에서 해당 앱과 버전의 최신 TestFlight 빌드 번호를 조회해 다음 `CURRENT_PROJECT_VERSION`을 계산합니다.

- `none`: 서버 버전 정책을 변경하지 않습니다.
- `recommended`: 기존 `minVersion`을 유지하고 `currentVersion`만 배포 버전으로 갱신합니다.
- `required`: `minVersion`과 `currentVersion`을 모두 배포 버전으로 갱신합니다.

버전 정책 스크립트는 기존 설정을 GET으로 조회하고, 버전 역행 여부를 확인한 다음 PATCH를 수행합니다. 이후 다시 GET을 수행해 반영 결과가 요청과 일치하는지 검증합니다.

## 배포 및 버전 관리 Workflow

Actions에는 사용자가 직접 실행하는 `Neki-iOS 배포 및 버전 관리` 워크플로만 표시됩니다. 앱별 공통 배포 절차는 Composite Action으로, 서버 버전 정책 처리는 스크립트로 관리하므로 내부 구현이 별도 실행 항목으로 노출되지 않습니다.

개발기와 상용기 Job은 각각 `development`, `production` Environment를 직접 선택합니다. 따라서 환경별 Secret은 다른 워크플로로 전달하거나 상속하지 않고 해당 Job에서만 읽습니다.

`Neki-iOS 배포 및 버전 관리`에서 다음 순서로 입력합니다.

1. 실행할 작업을 선택합니다.
2. 대상 앱을 Neki-dev, Neki-iOS, Neki-iOS & Dev 중에서 선택합니다.
3. 대상에 포함된 앱의 버전만 MAJOR.MINOR.PATCH 형식으로 입력합니다.
4. 서버 버전 정책을 함께 변경할 때만 권장 업데이트 또는 강제 업데이트를 선택합니다.
5. Neki-iOS 서버 정책을 변경할 때만 App Store 공개 확인란을 활성화합니다.

### 작업 종류

| 작업 | 실행 결과 |
| --- | --- |
| 연결 검증 | 선택한 앱의 인증·서명·App Store Connect 연결만 검증 |
| TestFlight 업로드 | 선택한 앱을 TestFlight에 업로드 |
| App Store 심사 제출 | Neki-iOS를 App Store 심사에 제출 |
| 서버 업데이트 정책만 적용 | 앱을 업로드하지 않고 선택한 환경의 버전 API만 갱신 |

Neki-iOS & Dev를 선택하면 개발기와 상용기를 독립된 Job에서 병렬 처리합니다. 두 앱의 버전 이력은 독립적이므로 development_version과 production_version을 각각 입력합니다.

release_notes는 선택 사항입니다. 비워두면 TestFlight 또는 App Store Connect에 릴리즈 노트를 새로 등록하지 않습니다. 입력한 내용은 Discord 결과 메시지에도 표시됩니다.

### 업데이트 정책

| 정책 | 서버 반영 |
| --- | --- |
| 변경 안 함 | 버전 API를 호출하지 않음 |
| 권장 업데이트 | 기존 minVersion을 유지하고 currentVersion만 입력 버전으로 변경 |
| 강제 업데이트 | minVersion과 currentVersion을 모두 입력 버전으로 변경 |

대상 앱이 Neki-dev일 때만 TestFlight 업로드 후 개발 서버 정책을 연속해서 적용할 수 있습니다. Neki-iOS는 TestFlight 업로드 직후 아직 App Store에 공개되지 않은 버전을 서버에 활성화하면 안 되므로, TestFlight 업로드와 서버 정책 적용을 분리합니다. 대상 앱이 Neki-iOS 또는 Neki-iOS & Dev이면 TestFlight 업로드와 업데이트 정책을 함께 선택할 수 없으며 입력 검증에서 종료됩니다.

Neki-iOS 서버 정책을 적용할 때는 대상 버전이 App Store에 실제 공개되었는지 확인한 뒤 "Neki-iOS 정책 적용 시, 해당 버전이 App Store에 공개됨을 확인" 항목을 활성화합니다. 연결 검증에는 업데이트 정책을 지정할 수 없고, App Store 심사 제출과 서버 정책 활성화도 한 번에 실행할 수 없습니다. 잘못된 조합은 앱 빌드 전에 입력 검증 단계에서 종료됩니다.

### 결과 판정

앱 처리와 서버 버전 정책은 별도 Job으로 실행되며 워크플로와 Discord에서 단계별 결과를 확인할 수 있습니다.

| Discord 표시 | 의미 |
| --- | --- |
| 초록색 성공 | 요청한 앱 처리와 버전 정책이 모두 성공 |
| 노란색 부분 성공 | 앱 업로드는 성공했지만 후속 버전 정책 반영 실패 |
| 빨간색 실패 | 입력 검증, 앱 검증·업로드 또는 정책만 적용하는 작업 실패 |

부분 성공도 요청한 전체 작업이 완료된 것은 아니므로 GitHub Actions 워크플로는 실패 상태를 유지합니다. 다만 Discord에는 앱 업로드 성공과 버전 정책 실패가 분리되어 표시되므로 이미 업로드된 빌드를 중복 배포하지 않고 실패한 정책 작업만 다시 실행할 수 있습니다.

연결 검증은 환경 리소스 복원, SPM 의존성 해석, GitHub App 토큰 발급, Ruby·Bundler 구성, App Store Connect 조회와 Match readonly 동기화까지만 수행합니다. Archive, 업로드와 버전 API PATCH는 실행하지 않습니다.

PR 본문이나 release 브랜치 머지를 배포 트리거로 사용하지 않습니다. 코드 검토·병합과 외부 배포를 분리하여 오기입이나 의도하지 않은 재실행이 실제 배포로 이어지는 것을 방지합니다.
