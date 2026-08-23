#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

debug() {
  echo "[debug] $*"
}

wait_for_url() {
  local url="$1"
  local timeout="${2:-90}"
  local i=0

  debug "waiting for HTTP 200 from ${url} (timeout ${timeout}s)"

  while [ "$i" -lt "$timeout" ]; do
    if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      debug "HTTP check passed: ${url}"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done

  echo "Timed out waiting for ${url}"
  return 1
}

wait_for_container() {
  local name="$1"
  local timeout="${2:-90}"
  local i=0

  debug "waiting for container ${name} to be running (timeout ${timeout}s)"

  while [ "$i" -lt "$timeout" ]; do
    if docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true; then
      debug "container check passed: ${name} is running"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done

  echo "Container ${name} did not start"
  return 1
}

remove_container() {
  debug "removing container ${1}"
  docker rm -f "$1" >/dev/null 2>&1 || true
}

start_dependencies() {
  docker compose -f "$COMPOSE_FILE" up -d --wait
}

stop_dependencies() {
  docker compose -f "$COMPOSE_FILE" down -v
}

run_http_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local host_port="$4"
  local container_port="$5"
  local path="$6"
  local command="$7"
  local container="oort-test-${label}"
  local url="http://127.0.0.1:${host_port}${path}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "command=${command}"
  debug "port mapping ${host_port}:${container_port}"
  debug "expect HTTP success at ${url}"
  remove_container "$container"

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    -p "${host_port}:${container_port}" \
    "$image" \
    $command

  wait_for_container "$container"
  wait_for_url "$url"
  debug "${label}: all checks passed"
  remove_container "$container"
}

run_exec_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local start_command="$4"
  local check_command="$5"
  local container="oort-test-${label}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "start command=${start_command}"
  debug "check command=${check_command}"
  remove_container "$container"

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $start_command

  wait_for_container "$container"
  debug "waiting 15s for ${label} to initialize"
  sleep 15
  debug "running check: ${check_command}"
  docker exec "$container" $check_command
  debug "${label}: check command succeeded"
  remove_container "$container"
}

run_worker_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local command="$4"
  local container="oort-test-${label}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=${command}"
  debug "expect artisan process to be running"
  remove_container "$container"

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $command

  wait_for_container "$container"
  debug "waiting 10s for ${label} worker to start"
  sleep 10

  if docker exec "$container" pgrep -f artisan >/dev/null 2>&1; then
    debug "process check passed: artisan worker is running in ${container}"
  else
    docker logs "$container"
    echo "Worker process not running for ${label}"
    return 1
  fi

  debug "${label}: all checks passed"
  remove_container "$container"
}

run_laravel_queue_worker_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local worker_command="$4"
  local container="oort-test-${label}"
  local attempt=0
  local max_attempts=15

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=${worker_command}"
  debug "job=App\\Jobs\\OortQueueHeartbeatJob (Redis queue heartbeat)"
  debug "expect worker process and processed job heartbeat"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan oort:dispatch-queue-heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $worker_command

  wait_for_container "$container"
  debug "waiting for ${label} worker to start"
  sleep 5

  if ! docker exec "$container" pgrep -f artisan >/dev/null 2>&1; then
    docker logs "$container"
    echo "Worker process not running for ${label}"
    return 1
  fi
  debug "process check passed: artisan worker is running in ${container}"

  debug "dispatching OortQueueHeartbeatJob to redis queue"
  docker exec "$container" php artisan oort:dispatch-queue-heartbeat --no-interaction

  while [ "$attempt" -lt "$max_attempts" ]; do
    attempt=$((attempt + 1))
    if heartbeat=$(docker exec "$container" php artisan oort:check-queue-heartbeat --no-interaction 2>/dev/null); then
      debug "queue heartbeat check passed (timestamp=${heartbeat})"
      remove_container "$container"
      debug "${label}: all checks passed"
      return 0
    fi
    debug "waiting for queue job to be processed (${attempt}/${max_attempts})"
    sleep 2
  done

  docker logs "$container"
  echo "Queue heartbeat was not recorded for ${label}"
  remove_container "$container"
  return 1
}

run_laravel_horizon_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local container="oort-test-${label}"
  local attempt=0
  local max_attempts=15

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=php artisan horizon"
  debug "job=App\\Jobs\\OortQueueHeartbeatJob (Redis queue heartbeat)"
  debug "expect horizon running, horizon:status OK, and processed job heartbeat"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan oort:dispatch-queue-heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan horizon

  wait_for_container "$container"
  debug "waiting 15s for ${label} to initialize"
  sleep 15

  if ! docker exec "$container" pgrep -f artisan >/dev/null 2>&1; then
    docker logs "$container"
    echo "Horizon process not running for ${label}"
    return 1
  fi
  debug "process check passed: horizon is running in ${container}"

  debug "running check: php artisan horizon:status"
  docker exec "$container" php artisan horizon:status --no-interaction

  debug "dispatching OortQueueHeartbeatJob to redis queue"
  docker exec "$container" php artisan oort:dispatch-queue-heartbeat --no-interaction

  while [ "$attempt" -lt "$max_attempts" ]; do
    attempt=$((attempt + 1))
    if heartbeat=$(docker exec "$container" php artisan oort:check-queue-heartbeat --no-interaction 2>/dev/null); then
      debug "queue heartbeat check passed (timestamp=${heartbeat})"
      remove_container "$container"
      debug "${label}: all checks passed"
      return 0
    fi
    debug "waiting for horizon to process job (${attempt}/${max_attempts})"
    sleep 2
  done

  docker logs "$container"
  echo "Horizon did not process queue heartbeat for ${label}"
  remove_container "$container"
  return 1
}

run_laravel_pulse_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local container="oort-test-${label}"
  local attempt=0
  local max_attempts=15

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=php artisan pulse:work"
  debug "entry=Pulse::record(oort_pulse_heartbeat) via oort:record-pulse-heartbeat"
  debug "expect pulse:work process and digested pulse_entries row"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan oort:record-pulse-heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan pulse:work

  wait_for_container "$container"
  debug "waiting for ${label} worker to start"
  sleep 5

  if ! docker exec "$container" pgrep -f "artisan pulse:work" >/dev/null 2>&1; then
    docker logs "$container"
    echo "Pulse worker process not running for ${label}"
    return 1
  fi
  debug "process check passed: pulse:work is running in ${container}"

  debug "recording Pulse heartbeat entry (redis ingest)"
  docker exec "$container" php artisan oort:record-pulse-heartbeat --no-interaction

  while [ "$attempt" -lt "$max_attempts" ]; do
    attempt=$((attempt + 1))
    if heartbeat=$(docker exec "$container" php artisan oort:check-pulse-heartbeat --no-interaction 2>/dev/null); then
      debug "pulse heartbeat check passed (timestamp=${heartbeat})"
      remove_container "$container"
      debug "${label}: all checks passed"
      return 0
    fi
    debug "waiting for pulse:work to digest entry (${attempt}/${max_attempts})"
    sleep 2
  done

  docker logs "$container"
  echo "Pulse heartbeat was not digested for ${label}"
  remove_container "$container"
  return 1
}

run_laravel_scheduler_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local container="oort-test-${label}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=php artisan schedule:work"
  debug "scheduled command=oort:heartbeat (everySecond in routes/console.php)"
  debug "expect schedule:work process and heartbeat after schedule:run"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan oort:heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php artisan schedule:work

  wait_for_container "$container"
  debug "waiting for ${label} worker to start"
  sleep 3

  if ! docker exec "$container" pgrep -f "artisan schedule:work" >/dev/null 2>&1; then
    docker logs "$container"
    echo "Scheduler process not running for ${label}"
    return 1
  fi
  debug "process check passed: schedule:work is running in ${container}"

  debug "running schedule:run for up to 5s"
  docker exec "$container" timeout 5 php artisan schedule:run --no-interaction || true

  if heartbeat=$(docker exec "$container" php artisan oort:check-heartbeat --no-interaction 2>/dev/null); then
    debug "heartbeat check passed: oort:heartbeat ran via scheduler (timestamp=${heartbeat})"
    remove_container "$container"
    debug "${label}: all checks passed"
    return 0
  fi

  docker logs "$container"
  echo "Scheduler heartbeat was not recorded for ${label}"
  remove_container "$container"
  return 1
}

run_symfony_http_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local host_port="$4"
  local container_port="$5"
  local path="$6"
  local command="$7"
  local container="oort-test-${label}"
  local url="http://127.0.0.1:${host_port}${path}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "command=${command}"
  debug "port mapping ${host_port}:${container_port}"
  debug "expect HTTP success at ${url}"
  remove_container "$container"

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    -p "${host_port}:${container_port}" \
    "$image" \
    $command

  wait_for_container "$container"
  wait_for_url "$url"
  debug "${label}: all checks passed"
  remove_container "$container"
}

run_symfony_messenger_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local worker_command="$4"
  local container="oort-test-${label}"
  local attempt=0
  local max_attempts=15

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=${worker_command}"
  debug "message=App\\Message\\OortMessengerHeartbeatMessage (Redis messenger heartbeat)"
  debug "expect worker process and processed message heartbeat"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php bin/console oort:dispatch-messenger-heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $worker_command

  wait_for_container "$container"
  debug "waiting for ${label} worker to start"
  sleep 5

  if ! docker exec "$container" pgrep -f "bin/console" >/dev/null 2>&1; then
    docker logs "$container"
    echo "Messenger worker process not running for ${label}"
    return 1
  fi
  debug "process check passed: bin/console worker is running in ${container}"

  debug "dispatching OortMessengerHeartbeatMessage to async transport"
  docker exec "$container" php bin/console oort:dispatch-messenger-heartbeat --no-interaction

  while [ "$attempt" -lt "$max_attempts" ]; do
    attempt=$((attempt + 1))
    if heartbeat=$(docker exec "$container" php bin/console oort:check-messenger-heartbeat --no-interaction 2>/dev/null); then
      debug "messenger heartbeat check passed (timestamp=${heartbeat})"
      remove_container "$container"
      debug "${label}: all checks passed"
      return 0
    fi
    debug "waiting for messenger to process message (${attempt}/${max_attempts})"
    sleep 2
  done

  docker logs "$container"
  echo "Messenger heartbeat was not recorded for ${label}"
  remove_container "$container"
  return 1
}

run_symfony_scheduler_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local worker_command="$4"
  local container="oort-test-${label}"
  local attempt=0
  local max_attempts=15

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=${worker_command}"
  debug "task=App\\Task\\OortSchedulerHeartbeat (AsPeriodicTask frequency=1s)"
  debug "expect scheduler worker and heartbeat from periodic task"
  remove_container "$container"

  docker run --rm \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    php bin/console oort:scheduler-heartbeat --clear --no-interaction

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $worker_command

  wait_for_container "$container"
  debug "waiting for ${label} worker to start"
  sleep 5

  if ! docker exec "$container" pgrep -f "bin/console" >/dev/null 2>&1; then
    docker logs "$container"
    echo "Scheduler worker process not running for ${label}"
    return 1
  fi
  debug "process check passed: bin/console worker is running in ${container}"

  while [ "$attempt" -lt "$max_attempts" ]; do
    attempt=$((attempt + 1))
    if heartbeat=$(docker exec "$container" php bin/console oort:check-scheduler-heartbeat --no-interaction 2>/dev/null); then
      debug "scheduler heartbeat check passed (timestamp=${heartbeat})"
      remove_container "$container"
      debug "${label}: all checks passed"
      return 0
    fi
    debug "waiting for scheduler task to run (${attempt}/${max_attempts})"
    sleep 2
  done

  docker logs "$container"
  echo "Scheduler heartbeat was not recorded for ${label}"
  remove_container "$container"
  return 1
}

run_symfony_worker_test() {
  local label="$1"
  local image="$2"
  local env_file="$3"
  local command="$4"
  local container="oort-test-${label}"

  echo "==> ${label}"
  debug "image=${image}"
  debug "worker command=${command}"
  debug "expect bin/console process to be running"
  remove_container "$container"

  docker run -d \
    --name "$container" \
    --network oort-test \
    --env-file "$env_file" \
    "$image" \
    $command

  wait_for_container "$container"
  debug "waiting 10s for ${label} worker to start"
  sleep 10

  if docker exec "$container" pgrep -f "bin/console" >/dev/null 2>&1; then
    debug "process check passed: bin/console worker is running in ${container}"
  else
    docker logs "$container"
    echo "Worker process not running for ${label}"
    return 1
  fi

  debug "${label}: all checks passed"
  remove_container "$container"
}
