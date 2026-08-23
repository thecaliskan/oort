<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

class OortCheckQueueHeartbeatCommand extends Command
{
    protected $signature = 'oort:check-queue-heartbeat';

    protected $description = 'Verify the OORT queue heartbeat job was processed';

    public function handle(): int
    {
        $heartbeat = Cache::store('redis')->get('oort:queue:heartbeat');

        if ($heartbeat === null) {
            $this->error('Queue heartbeat not found');

            return self::FAILURE;
        }

        $this->line((string) $heartbeat);

        return self::SUCCESS;
    }
}
