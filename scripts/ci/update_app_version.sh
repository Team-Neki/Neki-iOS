#!/bin/bash

set -euo pipefail

required_names=(
  APP_VERSION_API_ADDRESS
  APP_VERSION
  UPDATE_POLICY
)

for name in "${required_names[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "::error::Missing required environment variable: $name"
    exit 1
  fi
done

if [[ "$UPDATE_POLICY" != "recommended" && "$UPDATE_POLICY" != "required" ]]; then
  echo "::error::UPDATE_POLICY must be recommended or required: $UPDATE_POLICY"
  exit 1
fi

is_semantic_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

if ! is_semantic_version "$APP_VERSION"; then
  echo "::error::APP_VERSION must follow MAJOR.MINOR.PATCH: $APP_VERSION"
  exit 1
fi

version_is_less_than() {
  local left_major left_minor left_patch
  local right_major right_minor right_patch

  IFS='.' read -r left_major left_minor left_patch <<< "$1"
  IFS='.' read -r right_major right_minor right_patch <<< "$2"

  if (( left_major != right_major )); then (( left_major < right_major )); return; fi
  if (( left_minor != right_minor )); then (( left_minor < right_minor )); return; fi
  (( left_patch < right_patch ))
}

fetch_version_configuration() {
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --retry 2 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 30 \
    "$APP_VERSION_API_ADDRESS"
}

current_response=$(fetch_version_configuration)
current_minimum_version=$(jq -er '.data.minVersion | select(type == "string")' <<< "$current_response")
current_latest_version=$(jq -er '.data.currentVersion | select(type == "string")' <<< "$current_response")

if ! is_semantic_version "$current_minimum_version" ||
   ! is_semantic_version "$current_latest_version"; then
  echo "::error::Server versions must follow MAJOR.MINOR.PATCH"
  exit 1
fi

if version_is_less_than "$APP_VERSION" "$current_latest_version"; then
  echo "::error::Version regression is not allowed: $APP_VERSION < $current_latest_version"
  exit 1
fi

if version_is_less_than "$current_latest_version" "$current_minimum_version"; then
  echo "::error::Invalid server configuration: $current_minimum_version > $current_latest_version"
  exit 1
fi

if [ "$UPDATE_POLICY" = "recommended" ]; then
  target_minimum_version="$current_minimum_version"
else
  target_minimum_version="$APP_VERSION"
fi

if version_is_less_than "$APP_VERSION" "$target_minimum_version"; then
  echo "::error::Minimum version cannot exceed current version: $target_minimum_version > $APP_VERSION"
  exit 1
fi

request_body=$(jq -n \
  --arg minimum_version "$target_minimum_version" \
  --arg current_version "$APP_VERSION" \
  '{
    minVersion: $minimum_version,
    currentVersion: $current_version
  }')

curl \
  --fail-with-body \
  --silent \
  --show-error \
  --retry 2 \
  --retry-all-errors \
  --connect-timeout 10 \
  --max-time 30 \
  -X PATCH \
  "$APP_VERSION_API_ADDRESS" \
  -H "Content-Type: application/json" \
  -d "$request_body" > /dev/null

updated_response=$(fetch_version_configuration)
updated_minimum_version=$(jq -er '.data.minVersion | select(type == "string")' <<< "$updated_response")
updated_latest_version=$(jq -er '.data.currentVersion | select(type == "string")' <<< "$updated_response")

if [[ "$updated_minimum_version" != "$target_minimum_version" ||
      "$updated_latest_version" != "$APP_VERSION" ]]; then
  echo "::error::Version configuration verification failed"
  exit 1
fi

echo "Version policy updated: policy=$UPDATE_POLICY, minVersion=$updated_minimum_version, currentVersion=$updated_latest_version"
