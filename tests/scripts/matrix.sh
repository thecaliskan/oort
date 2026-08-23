#!/usr/bin/env bash
# Shared framework × PHP version matrix for CI and local runs.
set -euo pipefail

PHP_VERSIONS=(8.2 8.3 8.4 8.5 8.6-rc)
LARAVEL_VERSIONS=(12 13)
SYMFONY_VERSIONS=(7.4 8.0 8.1)

symfony_combo_supported() {
  local php="$1"
  local symfony="$2"

  if [ "$symfony" = "8.0" ] || [ "$symfony" = "8.1" ]; then
    case "$php" in
      8.4|8.5|8.6-rc) return 0 ;;
      *) return 1 ;;
    esac
  fi

  return 0
}

laravel_combo_supported() {
  local php="$1"
  local laravel="$2"

  if [ "$laravel" = "13" ]; then
    case "$php" in
      8.3|8.4|8.5|8.6-rc) return 0 ;;
      *) return 1 ;;
    esac
  fi

  return 0
}

laravel_image_tag() {
  local php="$1"
  local laravel="$2"
  echo "oort-test-laravel:${php}-${laravel}"
}

symfony_image_tag() {
  local php="$1"
  local symfony="$2"
  echo "oort-test-symfony:${php}-${symfony}"
}

laravel_matrix_json() {
  local entries=()

  for php in "${PHP_VERSIONS[@]}"; do
    for laravel in "${LARAVEL_VERSIONS[@]}"; do
      if laravel_combo_supported "$php" "$laravel"; then
        entries+=("{\"oort-version\":\"${php}\",\"laravel-version\":\"${laravel}\"}")
      fi
    done
  done

  local joined
  joined=$(IFS=,; echo "${entries[*]}")
  echo "{\"include\":[${joined}]}"
}

symfony_matrix_json() {
  local entries=()

  for php in "${PHP_VERSIONS[@]}"; do
    for symfony in "${SYMFONY_VERSIONS[@]}"; do
      if symfony_combo_supported "$php" "$symfony"; then
        entries+=("{\"oort-version\":\"${php}\",\"symfony-version\":\"${symfony}\"}")
      fi
    done
  done

  local joined
  joined=$(IFS=,; echo "${entries[*]}")
  echo "{\"include\":[${joined}]}"
}
