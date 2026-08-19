#!/bin/bash

set -euo pipefail

display_result() {
  case "$1" in
    success) echo "성공" ;;
    failure) echo "실패" ;;
    cancelled) echo "취소" ;;
    skipped) echo "미실행" ;;
    *) echo "확인 불가" ;;
  esac
}

has_delivery_success="false"
has_delivery_failure="false"
has_policy_failure="false"

evaluate_delivery_result() {
  local should_run="$1"
  local result="$2"
  if [ "$should_run" != "true" ]; then return; fi
  if [ "$result" = "success" ]; then
    has_delivery_success="true"
  else
    has_delivery_failure="true"
  fi
}

evaluate_policy_result() {
  local should_run="$1"
  local result="$2"
  if [ "$should_run" != "true" ]; then return; fi
  if [ "$result" != "success" ]; then has_policy_failure="true"; fi
}

run_development_delivery="false"
run_production_delivery="false"
run_development_policy="false"
run_production_policy="false"

if [ "$RUN_DELIVERY" = "true" ] && [ "$RUN_DEVELOPMENT" = "true" ]; then run_development_delivery="true"; fi
if [ "$RUN_DELIVERY" = "true" ] && [ "$RUN_PRODUCTION" = "true" ]; then run_production_delivery="true"; fi
if [ "$RUN_VERSION_POLICY" = "true" ] && [ "$RUN_DEVELOPMENT" = "true" ]; then run_development_policy="true"; fi
if [ "$RUN_VERSION_POLICY" = "true" ] && [ "$RUN_PRODUCTION" = "true" ]; then run_production_policy="true"; fi

evaluate_delivery_result "$run_development_delivery" "$DEVELOPMENT_DELIVERY_RESULT"
evaluate_delivery_result "$run_production_delivery" "$PRODUCTION_DELIVERY_RESULT"
evaluate_policy_result "$run_development_policy" "$DEVELOPMENT_POLICY_RESULT"
evaluate_policy_result "$run_production_policy" "$PRODUCTION_POLICY_RESULT"

if [ "$PREPARE_RESULT" != "success" ] || [ "$has_delivery_failure" = "true" ]; then
  title="❌ 지금까지 Neki-iOS를 사랑해주셔서 감사합니다."
  color=15548997
elif [ "$has_policy_failure" = "true" ] && [ "$has_delivery_success" = "true" ]; then
  title="⚠️ 앱 배포는 완료됐지만 버전 정책 반영을 확인해주세요."
  color=16705372
elif [ "$has_policy_failure" = "true" ]; then
  title="❌ 지금까지 Neki-iOS를 사랑해주셔서 감사합니다."
  color=15548997
else
  title="✅ 우리 Neki-iOS 정상영업 합니다."
  color=5763719
fi

payload=$(jq -n \
  --arg title "$title" \
  --arg operation "$OPERATION" \
  --arg target_app "$TARGET_APP" \
  --arg versions "${TARGET_VERSIONS:-입력 검증 실패}" \
  --arg update_policy "$UPDATE_POLICY_INPUT" \
  --arg prepare "$(display_result "$PREPARE_RESULT")" \
  --arg development_delivery "$(display_result "$DEVELOPMENT_DELIVERY_RESULT")" \
  --arg production_delivery "$(display_result "$PRODUCTION_DELIVERY_RESULT")" \
  --arg development_policy "$(display_result "$DEVELOPMENT_POLICY_RESULT")" \
  --arg production_policy "$(display_result "$PRODUCTION_POLICY_RESULT")" \
  --arg release_notes "$RELEASE_NOTES" \
  --argjson color "$color" \
  '($release_notes | if length > 1024 then .[0:1023] + "…" else . end) as $display_notes |
  {
    embeds: [{
      title: $title,
      color: $color,
      fields: ([
        {name: "작업 종류", value: $operation, inline: true},
        {name: "대상 앱", value: $target_app, inline: true},
        {name: "대상 버전", value: $versions, inline: true},
        {name: "업데이트 정책", value: $update_policy, inline: true},
        {name: "입력 검증", value: $prepare, inline: true},
        {name: "Neki-dev 앱 처리", value: $development_delivery, inline: true},
        {name: "Neki-iOS 앱 처리", value: $production_delivery, inline: true},
        {name: "Neki-dev 버전 정책", value: $development_policy, inline: true},
        {name: "Neki-iOS 버전 정책", value: $production_policy, inline: true}
      ] + (if $display_notes == "" then [] else [
        {name: "릴리즈 노트", value: $display_notes, inline: false}
      ] end))
    }]
  }')

curl --fail-with-body --silent --show-error \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$payload" \
  "$DISCORD_WEBHOOK_URL"
