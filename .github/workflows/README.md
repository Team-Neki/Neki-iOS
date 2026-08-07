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

Actions의 `Neki-iOS 배포 및 버전 관리`에서 실행할 작업을 선택합니다. 대상 환경, 배포 목적지와 업데이트 정책은 작업명에서 자동 결정됩니다.

Discord 결과 메시지의 대상 앱은 개발기를 `Neki-dev`, 상용기를 `Neki-iOS`로 표시합니다. 향후 두 앱을 함께 처리하는 작업은 `Neki-iOS & Dev`로 표시합니다.

| 작업 종류 | 실행 결과 |
| --- | --- |
| `개발기 연결 검증` | 개발기 인증·서명·App Store Connect 연결 검증 |
| `상용기 연결 검증` | 상용기 인증·서명·App Store Connect 연결 검증 |
| `개발기 TestFlight 업로드` | 개발기 TestFlight 업로드 |
| `개발기 TestFlight + 권장 업데이트` | 업로드 후 개발 서버에 권장 업데이트 적용 |
| `개발기 TestFlight + 강제 업데이트` | 업로드 후 개발 서버에 강제 업데이트 적용 |
| `상용기 TestFlight 업로드` | 상용기 TestFlight 업로드 |
| `상용기 App Store 심사 제출` | 상용기 App Store 심사 제출 |
| `상용기 권장 업데이트 활성화` | 공개된 상용 버전을 권장 업데이트로 활성화 |
| `상용기 강제 업데이트 활성화` | 공개된 상용 버전을 강제 업데이트로 활성화 |

모든 작업은 `app_version`을 입력합니다. TestFlight 및 App Store 심사 제출의 `release_notes`는 선택 사항입니다. 비워두면 릴리즈 노트를 새로 등록하지 않고 다음 단계로 진행합니다. 입력한 릴리즈 노트는 CI/CD 결과 Discord 메시지에도 표시되며, 비어 있으면 해당 항목을 생략합니다. 상용 버전 활성화 작업은 App Store 공개를 확인한 뒤 `production_release_confirmed`를 활성화해야 합니다.

`개발기 연결 검증`과 `상용기 연결 검증`은 환경 리소스 복원, SPM 의존성 해석, GitHub App 토큰 발급, Ruby·Bundler 구성, App Store Connect 조회와 Match readonly 동기화까지만 수행합니다. Archive, 업로드와 버전 API PATCH는 실행하지 않습니다.

PR 본문이나 release 브랜치 머지를 배포 트리거로 사용하지 않습니다. 코드 검토·병합과 외부 배포를 분리하여 오기입이나 의도하지 않은 재실행이 실제 배포로 이어지는 것을 방지합니다.
