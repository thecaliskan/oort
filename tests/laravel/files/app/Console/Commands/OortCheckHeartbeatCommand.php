<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

class OortCheckHeartbeatCommand extends Command
{
    protected $signature = 'oort:check-heartbeat';

    protected $description = 'Verify the OORT scheduler heartbeat exists';

    public function handle(): int
    {
        $heartbeat = Cache::store('redis')->get('oort:scheduler:heartbeat');

        if ($heartbeat === null) {
            $this->error('Scheduler heartbeat not found');

            return self::FAILURE;
        }

        $this->line((string) $heartbeat);

        return self::SUCCESS;
    }
}
