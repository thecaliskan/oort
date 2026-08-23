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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --laravel-only) RUN_SYMFONY=false ;;
    --symfony-only) RUN_LARAVEL=false ;;
    --php) FILTER_PHP="${2:?}"; shift ;;
    --laravel) FILTER_LARAVEL="${2:?}"; shift ;;
    --symfony) FILTER_SYMFONY="${2:?}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--laravel-only|--symfony-only] [--php 8.5] [--laravel 13] [--symfony 8.1]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

FAILED=()
SKIPPED=()

run_laravel_combo() {
  local php="$1"
  local laravel="$2"

  echo ""
  echo "########################################"
  echo "# Laravel ${laravel} on PHP ${php}"
  echo "########################################"

  set +e
  bash "${ROOT_DIR}/scripts/build-fixture.sh" laravel "$php" "$laravel"
  local build_status=$?
  set -e
  if [ "$build_status" -eq 2 ]; then
    echo "SKIP Laravel ${laravel} PHP ${php} (OORT image unavailable)"
    SKIPPED+=("laravel:${laravel}:php:${php}")
    return 0
  fi
  if [ "$build_status" -ne 0 ]; then
    echo "FAIL Laravel ${laravel} PHP ${php} (image build)"
    FAILED+=("laravel:${laravel}:php:${php}:build")
    return 0
  fi

  if bash "${ROOT_DIR}/scripts/laravel.sh" "$php" "$laravel"; then
    echo "PASS Laravel ${laravel} PHP ${php}"
  else
    echo "FAIL Laravel ${laravel} PHP ${php}"
    FAILED+=("laravel:${laravel}:php:${php}")
  fi
}

run_symfony_combo() {
  local php="$1"
  local symfony="$2"

  echo ""
  echo "########################################"
  echo "# Symfony ${symfony} on PHP ${php}"
  echo "########################################"

  set +e
  bash "${ROOT_DIR}/scripts/build-fixture.sh" symfony "$php" "$symfony"
  local build_status=$?
  set -e
  if [ "$build_status" -eq 2 ]; then
    echo "SKIP Symfony ${symfony} PHP ${php} (OORT image unavailable)"
    SKIPPED+=("symfony:${symfony}:php:${php}")
    return 0
  fi
  if [ "$build_status" -ne 0 ]; then
    echo "FAIL Symfony ${symfony} PHP ${php} (symfony image build)"
    FAILED+=("symfony:${symfony}:php:${php}:build")
    return 0
  fi

  if bash "${ROOT_DIR}/scripts/symfony.sh" "$php" "$symfony"; then
    echo "PASS Symfony ${symfony} PHP ${php}"
  else
    echo "FAIL Symfony ${symfony} PHP ${php}"
    FAILED+=("symfony:${symfony}:php:${php}")
  fi
}

start_dependencies

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
      run_laravel_combo "$php" "$laravel"
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
      run_symfony_combo "$php" "$symfony"
    done
  done
fi

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
