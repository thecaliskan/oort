#!/usr/bin/env bash
set -euo pipefail

PHP_VERSION="${1:?OORT/PHP version tag required}"
SYMFONY_VERSION="${2:-8.1}"
DOCKER_PLATFORM="${3:-${DOCKER_PLATFORM:-}}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/lib.sh"
# shellcheck source=matrix.sh
source "${ROOT_DIR}/scripts/matrix.sh"

if ! symfony_combo_supported "$PHP_VERSION" "$SYMFONY_VERSION"; then
  echo "Skipping Symfony ${SYMFONY_VERSION} on PHP ${PHP_VERSION} (incompatible)"
  exit 0
fi

IMAGE="$(symfony_image_tag "$PHP_VERSION" "$SYMFONY_VERSION")"
ENV_FILE="${ROOT_DIR}/symfony/.env"

echo "Running Symfony ${SYMFONY_VERSION} service tests with ${IMAGE} (PHP ${PHP_VERSION})"
if [ -n "$DOCKER_PLATFORM" ]; then
  echo "Platform: ${DOCKER_PLATFORM}"
fi

wait_for_postgres
wait_for_redis

debug "preparing database: php bin/console doctrine:schema:create --env=prod"
docker_run --rm \
  --network oort-test \
  --env-file "$ENV_FILE" \
  "$IMAGE" \
  php bin/console doctrine:schema:create --env=prod --no-interaction
debug "database schema check passed"

run_symfony_http_test \
  "symfony-${SYMFONY_VERSION}-runtime" \
  "$IMAGE" \
  "$ENV_FILE" \
  18082 \
  80 \
  /health \
  "php public/index.php"

run_symfony_messenger_test \
  "symfony-${SYMFONY_VERSION}-messenger" \
  "$IMAGE" \
  "$ENV_FILE" \
  "php bin/console messenger:consume async --time-limit=3600 --memory-limit=256M"

run_symfony_scheduler_test \
  "symfony-${SYMFONY_VERSION}-scheduler" \
  "$IMAGE" \
  "$ENV_FILE" \
  "php bin/console messenger:consume scheduler_default --time-limit=3600"

echo "Symfony ${SYMFONY_VERSION} service tests passed for PHP ${PHP_VERSION}"
