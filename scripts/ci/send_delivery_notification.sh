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

result_icon() {
  case "$1" in
    success) echo "✅" ;;
    failure) echo "❌" ;;
    cancelled) echo "⏹️" ;;
    skipped) echo "⏭️" ;;
    *) echo "❔" ;;
  esac
}

result_line() {
  local label="$1"
  local result="$2"
  printf '%s **%s** · %s' "$(result_icon "$result")" "$label" "$(display_result "$result")"
}

append_result_line() {
  local current="$1"
  local label="$2"
  local result="$3"
  local next
  next="$(result_line "$label" "$result")"

  if [ -z "$current" ]; then
    printf '%s' "$next"
  else
    printf '%s\n%s' "$current" "$next"
  fi
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
  summary="요청한 작업 중 실패한 단계를 확인해 주세요."
  color=15548997
elif [ "$has_policy_failure" = "true" ] && [ "$has_delivery_success" = "true" ]; then
  title="⚠️ 앱 배포는 완료됐지만 버전 정책 반영을 확인해주세요."
  summary="앱 처리는 완료됐지만 버전 정책 반영을 확인해야 합니다."
  color=16705372
elif [ "$has_policy_failure" = "true" ]; then
  title="❌ 지금까지 Neki-iOS를 사랑해주셔서 감사합니다."
  summary="버전 정책 반영에 실패했습니다."
  color=15548997
else
  title="✅ 우리 Neki-iOS 정상영업 합니다."
  summary="요청한 단계가 모두 정상적으로 완료되었습니다."
  color=5763719
fi

# 실행한 단계만 앱별로 묶어 성공·부분 성공·실패의 원인을 한눈에 구분합니다.
prepare_summary="$(result_line "입력 검증" "$PREPARE_RESULT")"
development_summary=""
production_summary=""

case "${DELIVERY_MODE:-none}" in
  validate) delivery_label="연결 검증" ;;
  deploy) delivery_label="앱 배포" ;;
  *) delivery_label="앱 처리" ;;
esac

if [ "$run_development_delivery" = "true" ]; then
  development_summary="$(append_result_line "$development_summary" "$delivery_label" "$DEVELOPMENT_DELIVERY_RESULT")"
fi
if [ "$run_production_delivery" = "true" ]; then
  production_summary="$(append_result_line "$production_summary" "$delivery_label" "$PRODUCTION_DELIVERY_RESULT")"
fi
if [ "$run_development_policy" = "true" ]; then
  development_summary="$(append_result_line "$development_summary" "버전 정책" "$DEVELOPMENT_POLICY_RESULT")"
fi
if [ "$run_production_policy" = "true" ]; then
  production_summary="$(append_result_line "$production_summary" "버전 정책" "$PRODUCTION_POLICY_RESULT")"
fi

payload=$(jq -n \
  --arg title "$title" \
  --arg summary "$summary" \
  --arg operation "$OPERATION" \
  --arg target_app "${TARGET_APP:-확인 불가}" \
  --arg versions "${TARGET_VERSIONS:-입력 검증 실패}" \
  --arg update_policy "$UPDATE_POLICY_INPUT" \
  --arg prepare_summary "$prepare_summary" \
  --arg development_summary "$development_summary" \
  --arg production_summary "$production_summary" \
  --arg release_notes "$RELEASE_NOTES" \
  --arg actor "${ACTION_ACTOR:-확인 불가}" \
  --arg actor_url "${ACTION_ACTOR_URL:-}" \
  --arg run_url "${ACTION_RUN_URL:-}" \
  --arg ref_name "${ACTION_REF_NAME:-확인 불가}" \
  --arg run_number "${ACTION_RUN_NUMBER:-?}" \
  --arg run_attempt "${ACTION_RUN_ATTEMPT:-?}" \
  --argjson color "$color" \
  '($release_notes | if length > 1000 then .[0:999] + "…" else . end) as $display_notes |
  ({
    embeds: [({
      title: $title,
      color: $color,
      description: ("**" + $operation + "**\n" + $summary),
      author: ({name: ("실행자 · @" + $actor)} +
        (if $actor_url == "" then {} else {url: $actor_url} end)),
      fields: ([
        {
          name: "📦 작업 대상",
          value: ("**앱** · " + $target_app + "\n**버전** · " + $versions),
          inline: false
        },
        {name: "🧪 입력 검증", value: $prepare_summary, inline: false}
      ] + (if $development_summary == "" then [] else [
        {name: "🟣 Neki-dev", value: $development_summary, inline: false}
      ] end) + (if $production_summary == "" then [] else [
        {name: "🔵 Neki-iOS", value: $production_summary, inline: false}
      ] end) + [
        {
          name: "⚙️ 실행 설정",
          value: ("**업데이트 정책** · " + $update_policy + "\n**브랜치** · `" + $ref_name + "`"),
          inline: false
        }
      ] + (if $display_notes == "" then [] else [
        {name: "📝 릴리즈 노트", value: $display_notes, inline: false}
      ] end)),
      footer: {text: ("Run #" + $run_number + " · Attempt " + $run_attempt)}
    } + (if $run_url == "" then {} else {url: $run_url} end))]
  })')

if [ "${DISCORD_DRY_RUN:-false}" = "true" ]; then
  printf '%s\n' "$payload"
  exit 0
fi

curl --fail-with-body --silent --show-error \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$payload" \
  "$DISCORD_WEBHOOK_URL"
