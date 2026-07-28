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
| `MATCH_GITHUB_APP_PRIVATE_KEY` | Match 저장소 읽기용 GitHub App private key |
| `MATCH_PASSWORD` | Match 저장소 암호화 비밀번호 |
| `DISCORD_WEBHOOK_URL` | 배포 결과 알림 Webhook |

다음 값은 Repository Variable로 관리합니다.

| Variable | Purpose |
| --- | --- |
| `MATCH_GITHUB_APP_ID` | Match 저장소 읽기용 GitHub App ID |

App Store Connect API Key는 현재 Team에 속하고 두 앱에 접근할 수 있어야 합니다. Key를 교체하면 `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`를 같은 Key 세트로 함께 갱신합니다.

GitHub App은 `Team-Neki/Neki-fastlane-match-repo`에만 설치하고 Repository Contents 읽기 권한만 부여합니다. 워크플로는 실행 시점에 1시간 이내로 유효한 Installation Token을 생성하며 Job 종료 시 폐기합니다. Match 저장소에는 개발기와 상용기 앱 및 Share Extension의 App Store 프로파일이 모두 포함되어야 합니다.

현재 Team의 서명 자산은 Match 저장소의 `team-P85DW78LYM` 브랜치에서 관리합니다. 해당 브랜치에는 Apple Distribution identity 1개와 개발기·상용기 앱 및 Share Extension용 App Store 프로파일 4개가 포함되어 있으며, Fastlane readonly 동기화로 검증됐습니다. 기존 `release` 브랜치는 이전 자산 보존 용도로만 두고 CI에서 사용하지 않습니다.

## Version policy

배포 버전은 `MAJOR.MINOR.PATCH` 형식으로 직접 입력합니다. Fastlane은 입력 버전을 Archive의 `MARKETING_VERSION`으로 사용하고 App Store Connect에서 해당 앱과 버전의 최신 TestFlight 빌드 번호를 조회해 다음 `CURRENT_PROJECT_VERSION`을 계산합니다.

- `none`: 서버 버전 정책을 변경하지 않습니다.
- `recommended`: 기존 `minVersion`을 유지하고 `currentVersion`만 배포 버전으로 갱신합니다.
- `required`: `minVersion`과 `currentVersion`을 모두 배포 버전으로 갱신합니다.

버전 정책 스크립트는 기존 설정을 GET으로 조회하고, 버전 역행 여부를 확인한 다음 PATCH를 수행합니다. 이후 다시 GET을 수행해 반영 결과가 요청과 일치하는지 검증합니다.

## Deployment workflow

Actions의 `iOS Deployment`를 수동 실행하고 다음 값을 입력합니다.

| Input | Description |
| --- | --- |
| `target` | `development` 또는 `production` |
| `marketing_version` | 배포할 `MAJOR.MINOR.PATCH` 버전 |
| `destination` | `testflight` 또는 `app_store_review` |
| `update_policy` | 개발 서버에 적용할 `none`, `recommended`, `required` |
| `release_notes` | TestFlight 테스트 내용 또는 App Store 업데이트 내용 |
| `validation_only` | Archive·업로드·버전 API 변경 없이 CI/CD 설정만 검증 |

`validation_only`을 활성화하면 환경 리소스 복원, SPM 의존성 해석, GitHub App 토큰 발급, Ruby·Bundler 구성, App Store Connect 인증과 TestFlight 조회, Match readonly 동기화까지만 수행합니다. Archive 생성, TestFlight·App Store 업로드, 버전 정책 PATCH는 실행하지 않습니다. 이 검증은 실제 Archive와 업로드 성공까지 보장하지 않으므로 최초 배포 전 사전 점검 용도로 사용합니다.

개발기는 TestFlight 업로드만 허용합니다. 선택한 경우 업로드 성공 후 개발 서버의 버전 정책을 갱신합니다.

상용기는 TestFlight 업로드와 App Store 심사 제출을 지원합니다. 심사 제출 시 한국어 릴리즈 노트를 반영하며 자동 출시는 사용하지 않습니다. 상용 서버의 버전 정책은 TestFlight 업로드 또는 심사 제출 시점에 변경하지 않습니다.

## Production version activation

상용 버전이 App Store에서 실제로 공개된 것을 확인한 후 `Activate App Version Policy`를 실행합니다.

1. `target`을 `production`으로 선택합니다.
2. 공개된 `app_version`을 입력합니다.
3. `recommended` 또는 `required`를 선택합니다.
4. `production_release_confirmed`를 활성화합니다.

이 단계를 분리하여 아직 설치할 수 없는 심사 중 버전으로 사용자를 업데이트시키는 문제를 방지합니다.
