#!/usr/bin/env bash
set -euo pipefail

PHP_VERSION="${1:?OORT/PHP version tag required}"
LARAVEL_VERSION="${2:-13}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/lib.sh"
# shellcheck source=matrix.sh
source "${ROOT_DIR}/scripts/matrix.sh"

if ! laravel_combo_supported "$PHP_VERSION" "$LARAVEL_VERSION"; then
  echo "Skipping Laravel ${LARAVEL_VERSION} on PHP ${PHP_VERSION} (incompatible)"
  exit 0
fi

IMAGE="$(laravel_image_tag "$PHP_VERSION" "$LARAVEL_VERSION")"
ENV_FILE="${ROOT_DIR}/laravel/.env"

echo "Running Laravel ${LARAVEL_VERSION} service tests with ${IMAGE} (PHP ${PHP_VERSION})"

debug "preparing database: php artisan migrate:fresh --force"
docker run --rm \
  --network oort-test \
  --env-file "$ENV_FILE" \
  "$IMAGE" \
  php artisan migrate:fresh --force --no-interaction
debug "database migration check passed"

run_http_test \
  "laravel-${LARAVEL_VERSION}-octane" \
  "$IMAGE" \
  "$ENV_FILE" \
  18080 \
  80 \
  /up \
  "php artisan octane:start --server=swoole --host=0.0.0.0 --port=80"

run_laravel_horizon_test \
  "laravel-${LARAVEL_VERSION}-horizon" \
  "$IMAGE" \
  "$ENV_FILE"

run_http_test \
  "laravel-${LARAVEL_VERSION}-reverb" \
  "$IMAGE" \
  "$ENV_FILE" \
  18081 \
  8080 \
  /up \
  "php artisan reverb:start --host=0.0.0.0 --port=8080"

run_laravel_queue_worker_test \
  "laravel-${LARAVEL_VERSION}-queue" \
  "$IMAGE" \
  "$ENV_FILE" \
  "php artisan queue:work redis --sleep=1 --tries=3 --max-time=3600"

run_laravel_scheduler_test \
  "laravel-${LARAVEL_VERSION}-scheduler" \
  "$IMAGE" \
  "$ENV_FILE"

run_laravel_pulse_test \
  "laravel-${LARAVEL_VERSION}-pulse" \
  "$IMAGE" \
  "$ENV_FILE"

echo "Laravel ${LARAVEL_VERSION} service tests passed for PHP ${PHP_VERSION}"
