<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

class OortHeartbeatCommand extends Command
{
    protected $signature = 'oort:heartbeat {--clear : Remove the scheduler heartbeat}';

    protected $description = 'Record a scheduler heartbeat for OORT integration tests';

    public function handle(): int
    {
        if ($this->option('clear')) {
            Cache::store('redis')->forget('oort:scheduler:heartbeat');

            return self::SUCCESS;
        }

        Cache::store('redis')->put('oort:scheduler:heartbeat', time(), 300);

        return self::SUCCESS;
    }
}
