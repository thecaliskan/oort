#!/usr/bin/env sh
set -eu

LARAVEL_VERSION="${LARAVEL_VERSION:-13.0}"

composer create-project "laravel/laravel:^${LARAVEL_VERSION}" /tmp/laravel --no-interaction --prefer-dist --no-dev --no-scripts
cp -a /tmp/laravel/. .
rm -rf /tmp/laravel

php artisan package:discover --no-interaction 2>/dev/null || true

composer require \
  laravel/octane \
  laravel/horizon \
  laravel/reverb \
  laravel/pulse \
  predis/predis \
  --no-interaction --optimize-autoloader -W

php artisan package:discover --no-interaction

php artisan vendor:publish --tag=octane-config --no-interaction --force
php artisan horizon:install --no-interaction
php artisan vendor:publish --tag=reverb-config --no-interaction --force
php artisan vendor:publish --provider="Laravel\Pulse\PulseServiceProvider" --no-interaction

mkdir -p app/Console/Commands app/Jobs
cp /tmp/files/app/Console/Commands/OortHeartbeatCommand.php app/Console/Commands/OortHeartbeatCommand.php
cp /tmp/files/app/Console/Commands/OortCheckHeartbeatCommand.php app/Console/Commands/OortCheckHeartbeatCommand.php
cp /tmp/files/app/Console/Commands/OortDispatchQueueHeartbeatCommand.php app/Console/Commands/OortDispatchQueueHeartbeatCommand.php
cp /tmp/files/app/Console/Commands/OortCheckQueueHeartbeatCommand.php app/Console/Commands/OortCheckQueueHeartbeatCommand.php
cp /tmp/files/app/Console/Commands/OortRecordPulseHeartbeatCommand.php app/Console/Commands/OortRecordPulseHeartbeatCommand.php
cp /tmp/files/app/Console/Commands/OortCheckPulseHeartbeatCommand.php app/Console/Commands/OortCheckPulseHeartbeatCommand.php
cp /tmp/files/app/Jobs/OortQueueHeartbeatJob.php app/Jobs/OortQueueHeartbeatJob.php

if ! grep -q 'oort:heartbeat' routes/console.php; then
  if ! grep -q 'use Illuminate\\Support\\Facades\\Schedule;' routes/console.php; then
    sed -i '/use Illuminate\\Support\\Facades\\Artisan;/a use Illuminate\\Support\\Facades\\Schedule;' routes/console.php
  fi
  printf '\nSchedule::command('\''oort:heartbeat'\'')->everySecond();\n' >> routes/console.php
fi

cat > .env <<'EOF'
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

QUEUE_CONNECTION=redis
SESSION_DRIVER=file
CACHE_STORE=redis
BROADCAST_CONNECTION=reverb

REVERB_APP_ID=app
REVERB_APP_KEY=key
REVERB_APP_SECRET=secret
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=http

PULSE_ENABLED=true
PULSE_INGEST_DRIVER=redis

OCTANE_SERVER=swoole
EOF

php artisan key:generate --force

php <<'PHP'
$path = 'bootstrap/app.php';
$contents = file_get_contents($path);
if (!str_contains($contents, "health: '/up'")) {
    $contents = preg_replace(
        '/->withRouting\(\s*/',
        "->withRouting(\n        health: '/up',\n        ",
        $contents,
        1
    );
    file_put_contents($path, $contents);
}
PHP

php artisan config:cache
php artisan route:cache
