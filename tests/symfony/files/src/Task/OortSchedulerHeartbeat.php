<?php

namespace App\Task;

use Predis\Client;
use Symfony\Component\Scheduler\Attribute\AsPeriodicTask;

#[AsPeriodicTask(frequency: 1)]
final class OortSchedulerHeartbeat
{
    public function __invoke(): void
    {
        $redis = new Client($_ENV['REDIS_URL']);
        $redis->set('oort:scheduler:heartbeat', (string) time());
        $redis->expire('oort:scheduler:heartbeat', 300);
    }
}
