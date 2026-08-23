#!/usr/bin/env bash
set -euo pipefail

FRAMEWORK="${1:?framework: laravel|symfony}"
PHP_VERSION="${2:?OORT/PHP tag, e.g. 8.5}"
FRAMEWORK_VERSION="${3:?framework version, e.g. 13 or 7.4}"
PLATFORM="${4:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=matrix.sh
source "${ROOT_DIR}/scripts/matrix.sh"

if [ -n "$PLATFORM" ]; then
  export DOCKER_PLATFORM="$PLATFORM"
fi

OORT_IMAGE="thecaliskan/oort:${PHP_VERSION}"

case "$FRAMEWORK" in
  laravel)
    if ! laravel_combo_supported "$PHP_VERSION" "$FRAMEWORK_VERSION"; then
      echo "Unsupported combination: Laravel ${FRAMEWORK_VERSION} on PHP ${PHP_VERSION}"
      exit 1
    fi
    TAG="$(laravel_image_tag "$PHP_VERSION" "$FRAMEWORK_VERSION")"
    CONTEXT="${ROOT_DIR}/laravel"
    BUILD_ARGS=(
      --build-arg "OORT_IMAGE=${OORT_IMAGE}"
      --build-arg "LARAVEL_VERSION=${FRAMEWORK_VERSION}.0"
    )
    ;;
  symfony)
    if ! symfony_combo_supported "$PHP_VERSION" "$FRAMEWORK_VERSION"; then
      echo "Unsupported combination: Symfony ${FRAMEWORK_VERSION} on PHP ${PHP_VERSION}"
      exit 1
    fi
    TAG="$(symfony_image_tag "$PHP_VERSION" "$FRAMEWORK_VERSION")"
    CONTEXT="${ROOT_DIR}/symfony"
    BUILD_ARGS=(
      --build-arg "OORT_IMAGE=${OORT_IMAGE}"
      --build-arg "SYMFONY_VERSION=${FRAMEWORK_VERSION}"
    )
    ;;
  *)
    echo "Unknown framework: ${FRAMEWORK}"
    exit 1
    ;;
esac

echo "==> Building ${TAG}"
if [ -n "$PLATFORM" ]; then
  echo "    platform: ${PLATFORM}"
fi

PULL_ARGS=()
BUILD_PLATFORM_ARGS=()
if [ -n "$PLATFORM" ]; then
  PULL_ARGS=(--platform "$PLATFORM")
  BUILD_PLATFORM_ARGS=(--platform "$PLATFORM")
fi

if ! docker pull "${PULL_ARGS[@]}" "$OORT_IMAGE"; then
  echo "SKIP: OORT image ${OORT_IMAGE} is not available"
  exit 2
fi
docker build "${BUILD_PLATFORM_ARGS[@]}" -t "$TAG" "${BUILD_ARGS[@]}" "$CONTEXT"
