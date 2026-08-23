<?php

namespace App\MessageHandler;

use App\Message\OortMessengerHeartbeatMessage;
use Predis\Client;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final class OortMessengerHeartbeatHandler
{
    public function __invoke(OortMessengerHeartbeatMessage $message): void
    {
        $redis = new Client($_ENV['REDIS_URL']);
        $redis->set('oort:messenger:heartbeat', (string) time());
        $redis->expire('oort:messenger:heartbeat', 300);
    }
}
