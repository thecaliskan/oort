#!/usr/bin/env sh
set -eu

SYMFONY_VERSION="${SYMFONY_VERSION:-8.1}"

composer create-project "symfony/skeleton:^${SYMFONY_VERSION}" /tmp/symfony --no-interaction --prefer-dist --no-dev --no-scripts
cp -a /tmp/symfony/. .
rm -rf /tmp/symfony

composer config name app/oort-test
composer config minimum-stability dev
composer config prefer-stable true

export APP_ENV=prod

composer require \
  runtime/swoole \
  symfony/messenger \
  symfony/redis-messenger \
  symfony/scheduler \
  predis/predis \
  --no-interaction --optimize-autoloader -W --no-scripts

composer require \
  doctrine/doctrine-bundle \
  doctrine/orm:^3.6 \
  doctrine/doctrine-migrations-bundle \
  --no-interaction --optimize-autoloader -W --no-scripts

cp /tmp/files/src/Controller/HealthController.php src/Controller/HealthController.php
mkdir -p src/Task src/Message src/MessageHandler src/Command
cp /tmp/files/src/Task/CleanupOldRecords.php src/Task/CleanupOldRecords.php
cp /tmp/files/src/Task/OortSchedulerHeartbeat.php src/Task/OortSchedulerHeartbeat.php
cp /tmp/files/src/Message/OortMessengerHeartbeatMessage.php src/Message/OortMessengerHeartbeatMessage.php
cp /tmp/files/src/MessageHandler/OortMessengerHeartbeatHandler.php src/MessageHandler/OortMessengerHeartbeatHandler.php
cp /tmp/files/src/Command/OortDispatchMessengerHeartbeatCommand.php src/Command/OortDispatchMessengerHeartbeatCommand.php
cp /tmp/files/src/Command/OortCheckMessengerHeartbeatCommand.php src/Command/OortCheckMessengerHeartbeatCommand.php
cp /tmp/files/src/Command/OortSchedulerHeartbeatCommand.php src/Command/OortSchedulerHeartbeatCommand.php
cp /tmp/files/src/Command/OortCheckSchedulerHeartbeatCommand.php src/Command/OortCheckSchedulerHeartbeatCommand.php
cp /tmp/files/config/packages/messenger.yaml config/packages/messenger.yaml

php <<'PHP'
$composer = json_decode(file_get_contents('composer.json'), true, 512, JSON_THROW_ON_ERROR);
$runtime = json_decode(file_get_contents('/tmp/files/composer.runtime.json'), true, 512, JSON_THROW_ON_ERROR);
$composer['extra'] = array_merge($composer['extra'] ?? [], $runtime);
file_put_contents('composer.json', json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
PHP

cat > .env <<'EOF'
APP_ENV=prod
APP_SECRET=ChangeMeSymfonySecretKeyForOortTests
DEFAULT_URI=http://localhost
DATABASE_URL="postgresql://app:secret@postgres:5432/app?serverVersion=16&charset=utf8"
REDIS_URL=redis://redis:6379
MESSENGER_TRANSPORT_DSN=redis://redis:6379/messages
APP_RUNTIME=Runtime\Swoole\Runtime
SWOOLE_HOST=0.0.0.0
SWOOLE_PORT=80
EOF

php bin/console cache:clear --env=prod --no-interaction
php bin/console cache:warmup --env=prod --no-interaction
