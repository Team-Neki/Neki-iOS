#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFICATION_SCRIPT="$SCRIPT_DIR/send_delivery_notification.sh"

render_notification() {
  env \
    DISCORD_DRY_RUN=true \
    OPERATION="Neki-iOS & Dev 연결 검증" \
    TARGET_APP="Neki-iOS & Dev" \
    TARGET_VERSIONS="Neki-dev 1.2.3 / Neki-iOS 1.2.3" \
    UPDATE_POLICY_INPUT="변경 안 함" \
    RELEASE_NOTES="" \
    DELIVERY_MODE=validate \
    RUN_DELIVERY=true \
    RUN_VERSION_POLICY=false \
    RUN_DEVELOPMENT=true \
    RUN_PRODUCTION=true \
    PREPARE_RESULT=success \
    DEVELOPMENT_DELIVERY_RESULT=success \
    PRODUCTION_DELIVERY_RESULT=success \
    DEVELOPMENT_POLICY_RESULT=skipped \
    PRODUCTION_POLICY_RESULT=skipped \
    ACTION_ACTOR=ci-tester \
    ACTION_ACTOR_URL=https://github.com/ci-tester \
    ACTION_RUN_URL=https://github.com/Team-Neki/Neki-iOS/actions/runs/1 \
    ACTION_REF_NAME=fix/notification-layout \
    ACTION_RUN_NUMBER=1 \
    ACTION_RUN_ATTEMPT=1 \
    "$@" \
    "$NOTIFICATION_SCRIPT"
}

assert_layout() {
  local scenario="$1"
  local expected_title="$2"
  local expected_fields="$3"
  local payload="$4"

  jq -e \
    --arg title "$expected_title" \
    --argjson fields "$expected_fields" \
    '.embeds[0] | .title == $title and ([.fields[].name] == $fields)' \
    <<< "$payload" > /dev/null || {
      echo "Notification layout failed: $scenario" >&2
      return 1
    }
}

success_title="✅ 우리 Neki-iOS 정상영업 합니다."
partial_title="⚠️ 앱 배포는 완료됐지만 버전 정책 반영을 확인해주세요."
failure_title="❌ 지금까지 Neki-iOS를 사랑해주셔서 감사합니다."

payload="$(render_notification)"
assert_layout \
  "dual validation success" \
  "$success_title" \
  '["📦 작업 대상","🧪 입력 검증","🟣 Neki-dev","🔵 Neki-iOS","⚙️ 실행 설정"]' \
  "$payload"
jq -e '.embeds[0].fields[] | select(.name == "🟣 Neki-dev") | .value | contains("연결 검증")' \
  <<< "$payload" > /dev/null

payload="$(render_notification \
  OPERATION="Neki-dev TestFlight 업로드" \
  TARGET_APP=Neki-dev \
  DELIVERY_MODE=deploy \
  RUN_PRODUCTION=false \
  RUN_VERSION_POLICY=true \
  DEVELOPMENT_POLICY_RESULT=failure)"
assert_layout \
  "delivery partial success" \
  "$partial_title" \
  '["📦 작업 대상","🧪 입력 검증","🟣 Neki-dev","⚙️ 실행 설정"]' \
  "$payload"
jq -e '.embeds[0].fields[] | select(.name == "🟣 Neki-dev") | .value | contains("앱 배포") and contains("버전 정책")' \
  <<< "$payload" > /dev/null

payload="$(render_notification \
  OPERATION="Neki-iOS TestFlight 업로드" \
  TARGET_APP=Neki-iOS \
  DELIVERY_MODE=deploy \
  RUN_DEVELOPMENT=false \
  PRODUCTION_DELIVERY_RESULT=failure)"
assert_layout \
  "delivery failure" \
  "$failure_title" \
  '["📦 작업 대상","🧪 입력 검증","🔵 Neki-iOS","⚙️ 실행 설정"]' \
  "$payload"

payload="$(render_notification \
  OPERATION="Neki-iOS & Dev 서버 업데이트 정책만 적용" \
  DELIVERY_MODE=none \
  RUN_DELIVERY=false \
  RUN_VERSION_POLICY=true \
  DEVELOPMENT_DELIVERY_RESULT=skipped \
  PRODUCTION_DELIVERY_RESULT=skipped \
  DEVELOPMENT_POLICY_RESULT=success \
  PRODUCTION_POLICY_RESULT=success)"
assert_layout \
  "policy-only success" \
  "$success_title" \
  '["📦 작업 대상","🧪 입력 검증","🟣 Neki-dev","🔵 Neki-iOS","⚙️ 실행 설정"]' \
  "$payload"

payload="$(render_notification \
  TARGET_APP= \
  TARGET_VERSIONS= \
  RUN_DELIVERY= \
  RUN_VERSION_POLICY= \
  RUN_DEVELOPMENT= \
  RUN_PRODUCTION= \
  PREPARE_RESULT=failure \
  DEVELOPMENT_DELIVERY_RESULT=skipped \
  PRODUCTION_DELIVERY_RESULT=skipped)"
assert_layout \
  "input validation failure" \
  "$failure_title" \
  '["📦 작업 대상","🧪 입력 검증","⚙️ 실행 설정"]' \
  "$payload"

echo "Discord notification layout: all scenarios passed"
