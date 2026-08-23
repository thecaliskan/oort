#!/usr/bin/env bash
# Verify all OORT PHP extensions load without startup warnings on a given platform.
set -euo pipefail

IMAGE="${1:?Docker image required (e.g. thecaliskan/oort:8.5)}"
PLATFORM="${2:-}"

REQUIRED_EXTENSIONS=(
  igbinary
  redis
  swoole
  ssh2
  bcmath
  ftp
  intl
  pcntl
  pdo_mysql
  pdo_pgsql
  zip
)

run_php() {
  local args=()
  if [ -n "$PLATFORM" ]; then
    args+=(--platform "$PLATFORM")
  fi
  docker run --rm "${args[@]}" "$IMAGE" php "$@"
}

label="${PLATFORM:-native}"
echo "==> verifying PHP extensions: ${IMAGE} (${label})"

modules_output="$(run_php -m 2>&1)" || {
  echo "$modules_output"
  exit 1
}

if grep -qiE 'PHP Warning:.*Unable to load dynamic library' <<<"$modules_output"; then
  echo "FAIL (${label}): PHP startup warnings while loading extensions:"
  grep -i 'PHP Warning' <<<"$modules_output"
  exit 1
fi

missing=()
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
  if ! run_php -r "exit(extension_loaded('${ext}') ? 0 : 1);" 2>/dev/null; then
    missing+=("$ext")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "FAIL (${label}): extensions not loaded: ${missing[*]}"
  echo "$modules_output"
  exit 1
fi

echo "OK (${label}): ${#REQUIRED_EXTENSIONS[@]} extensions loaded"
