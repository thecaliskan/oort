#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/lib.sh"
# shellcheck source=matrix.sh
source "${ROOT_DIR}/scripts/matrix.sh"

RUN_LARAVEL=true
RUN_SYMFONY=true
FILTER_PHP=""
FILTER_LARAVEL=""
FILTER_SYMFONY=""
FILTER_PLATFORM=""
RUN_ALL_PLATFORMS=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --laravel-only) RUN_SYMFONY=false ;;
    --symfony-only) RUN_LARAVEL=false ;;
    --all-platforms) RUN_ALL_PLATFORMS=true ;;
    --php) FILTER_PHP="${2:?}"; shift ;;
    --laravel) FILTER_LARAVEL="${2:?}"; shift ;;
    --symfony) FILTER_SYMFONY="${2:?}"; shift ;;
    --platform) FILTER_PLATFORM="${2:?}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--laravel-only|--symfony-only] [--all-platforms] [--php 8.5] [--laravel 13] [--symfony 8.1] [--platform linux/amd64]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

platforms_for_run() {
  if [ -n "$FILTER_PLATFORM" ]; then
    printf '%s\n' "$FILTER_PLATFORM"
    return
  fi
  if [ "$RUN_ALL_PLATFORMS" = true ]; then
    printf '%s\n' "${OORT_PLATFORMS[@]}"
    return
  fi
  printf '\n'
}

FAILED=()
SKIPPED=()

run_laravel_combo() {
  local php="$1"
  local laravel="$2"
  local platform="$3"

  echo ""
  echo "########################################"
  if [ -n "$platform" ]; then
    echo "# Laravel ${laravel} on PHP ${php} (${platform})"
  else
    echo "# Laravel ${laravel} on PHP ${php}"
  fi
  echo "########################################"

  if [ -n "$platform" ]; then
    export DOCKER_PLATFORM="$platform"
  else
    unset DOCKER_PLATFORM
  fi

  set +e
  bash "${ROOT_DIR}/scripts/build-fixture.sh" laravel "$php" "$laravel" "$platform"
  local build_status=$?
  set -e
  if [ "$build_status" -eq 2 ]; then
    echo "SKIP Laravel ${laravel} PHP ${php} (OORT image unavailable)"
    SKIPPED+=("laravel:${laravel}:php:${php}:${platform:-native}")
    return 0
  fi
  if [ "$build_status" -ne 0 ]; then
    echo "FAIL Laravel ${laravel} PHP ${php} (image build)"
    FAILED+=("laravel:${laravel}:php:${php}:${platform:-native}:build")
    return 0
  fi

  if bash "${ROOT_DIR}/scripts/laravel.sh" "$php" "$laravel" "$platform"; then
    echo "PASS Laravel ${laravel} PHP ${php} (${platform:-native})"
  else
    echo "FAIL Laravel ${laravel} PHP ${php} (${platform:-native})"
    FAILED+=("laravel:${laravel}:php:${php}:${platform:-native}")
  fi
}

run_symfony_combo() {
  local php="$1"
  local symfony="$2"
  local platform="$3"

  echo ""
  echo "########################################"
  if [ -n "$platform" ]; then
    echo "# Symfony ${symfony} on PHP ${php} (${platform})"
  else
    echo "# Symfony ${symfony} on PHP ${php}"
  fi
  echo "########################################"

  if [ -n "$platform" ]; then
    export DOCKER_PLATFORM="$platform"
  else
    unset DOCKER_PLATFORM
  fi

  set +e
  bash "${ROOT_DIR}/scripts/build-fixture.sh" symfony "$php" "$symfony" "$platform"
  local build_status=$?
  set -e
  if [ "$build_status" -eq 2 ]; then
    echo "SKIP Symfony ${symfony} PHP ${php} (OORT image unavailable)"
    SKIPPED+=("symfony:${symfony}:php:${php}:${platform:-native}")
    return 0
  fi
  if [ "$build_status" -ne 0 ]; then
    echo "FAIL Symfony ${symfony} PHP ${php} (symfony image build)"
    FAILED+=("symfony:${symfony}:php:${php}:${platform:-native}:build")
    return 0
  fi

  if bash "${ROOT_DIR}/scripts/symfony.sh" "$php" "$symfony" "$platform"; then
    echo "PASS Symfony ${symfony} PHP ${php} (${platform:-native})"
  else
    echo "FAIL Symfony ${symfony} PHP ${php} (${platform:-native})"
    FAILED+=("symfony:${symfony}:php:${php}:${platform:-native}")
  fi
}

start_dependencies

while IFS= read -r platform; do
  if [ "$RUN_LARAVEL" = true ]; then
    for php in "${PHP_VERSIONS[@]}"; do
      if [ -n "$FILTER_PHP" ] && [ "$php" != "$FILTER_PHP" ]; then
        continue
      fi
      for laravel in "${LARAVEL_VERSIONS[@]}"; do
        if [ -n "$FILTER_LARAVEL" ] && [ "$laravel" != "$FILTER_LARAVEL" ]; then
          continue
        fi
        if ! laravel_combo_supported "$php" "$laravel"; then
          continue
        fi
        run_laravel_combo "$php" "$laravel" "$platform"
      done
    done
  fi

  if [ "$RUN_SYMFONY" = true ]; then
    for php in "${PHP_VERSIONS[@]}"; do
      if [ -n "$FILTER_PHP" ] && [ "$php" != "$FILTER_PHP" ]; then
        continue
      fi
      for symfony in "${SYMFONY_VERSIONS[@]}"; do
        if [ -n "$FILTER_SYMFONY" ] && [ "$symfony" != "$FILTER_SYMFONY" ]; then
          continue
        fi
        if ! symfony_combo_supported "$php" "$symfony"; then
          continue
        fi
        run_symfony_combo "$php" "$symfony" "$platform"
      done
    done
  fi
done < <(platforms_for_run)

stop_dependencies

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo ""
  echo "Skipped combinations:"
  printf '  %s\n' "${SKIPPED[@]}"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo ""
  echo "Failed combinations:"
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi

echo ""
echo "All framework matrix tests passed."
