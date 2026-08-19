#!/bin/bash

set -euo pipefail

case "$OPERATION" in
  "연결 검증")
    delivery_mode="validate"
    distribution_destination="testflight"
    run_delivery="true"
    ;;
  "TestFlight 업로드")
    delivery_mode="deploy"
    distribution_destination="testflight"
    run_delivery="true"
    ;;
  "App Store 심사 제출")
    delivery_mode="deploy"
    distribution_destination="app_store_review"
    run_delivery="true"
    ;;
  "서버 업데이트 정책만 적용")
    delivery_mode="none"
    distribution_destination="none"
    run_delivery="false"
    ;;
  *)
    echo "::error::지원하지 않는 작업입니다: $OPERATION"
    exit 1
    ;;
esac

case "$TARGET_APP" in
  "Neki-dev")
    run_development="true"
    run_production="false"
    ;;
  "Neki-iOS")
    run_development="false"
    run_production="true"
    ;;
  "Neki-iOS & Dev")
    run_development="true"
    run_production="true"
    ;;
  *)
    echo "::error::지원하지 않는 대상 앱입니다: $TARGET_APP"
    exit 1
    ;;
esac

case "$UPDATE_POLICY_INPUT" in
  "변경 안 함") update_policy="none" ;;
  "권장 업데이트") update_policy="recommended" ;;
  "강제 업데이트") update_policy="required" ;;
  *)
    echo "::error::지원하지 않는 업데이트 정책입니다: $UPDATE_POLICY_INPUT"
    exit 1
    ;;
esac

run_version_policy="false"
if [ "$update_policy" != "none" ]; then run_version_policy="true"; fi

if [ "$OPERATION" = "연결 검증" ] && [ "$run_version_policy" = "true" ]; then
  echo "::error::연결 검증은 서버 버전 정책을 변경하지 않습니다"
  exit 1
fi

if [ "$OPERATION" = "서버 업데이트 정책만 적용" ] && [ "$run_version_policy" = "false" ]; then
  echo "::error::서버 정책만 적용할 때는 권장 또는 강제 업데이트를 선택해야 합니다"
  exit 1
fi

if [ "$OPERATION" = "App Store 심사 제출" ]; then
  if [ "$TARGET_APP" != "Neki-iOS" ]; then
    echo "::error::App Store 심사 제출은 Neki-iOS만 대상으로 선택할 수 있습니다"
    exit 1
  fi
  if [ "$run_version_policy" = "true" ]; then
    echo "::error::App Store 심사 제출과 서버 버전 정책 활성화는 분리해서 실행해야 합니다"
    exit 1
  fi
fi

if [ "$OPERATION" = "TestFlight 업로드" ] &&
   [ "$run_production" = "true" ] &&
   [ "$run_version_policy" = "true" ]; then
  echo "::error::Neki-iOS TestFlight 업로드와 서버 버전 정책 활성화는 분리해서 실행해야 합니다"
  exit 1
fi

if [ "$run_production" = "true" ] &&
   [ "$run_version_policy" = "true" ] &&
   [ "$PRODUCTION_VERSION_IS_LIVE" != "true" ]; then
  echo "::error::Neki-iOS 서버 버전 정책은 해당 버전의 App Store 공개를 확인한 후에만 적용할 수 있습니다"
  exit 1
fi

validate_version() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "::error::${name}은 MAJOR.MINOR.PATCH 형식으로 입력해야 합니다"
    exit 1
  fi
}

target_versions=""
if [ "$run_development" = "true" ]; then
  validate_version "development_version" "$DEVELOPMENT_VERSION"
  target_versions="Neki-dev $DEVELOPMENT_VERSION"
fi
if [ "$run_production" = "true" ]; then
  validate_version "production_version" "$PRODUCTION_VERSION"
  if [ -n "$target_versions" ]; then target_versions="$target_versions / "; fi
  target_versions="${target_versions}Neki-iOS $PRODUCTION_VERSION"
fi

{
  echo "delivery_mode=$delivery_mode"
  echo "distribution_destination=$distribution_destination"
  echo "update_policy=$update_policy"
  echo "run_delivery=$run_delivery"
  echo "run_version_policy=$run_version_policy"
  echo "run_development=$run_development"
  echo "run_production=$run_production"
  echo "target_versions=$target_versions"
} >> "$GITHUB_OUTPUT"
