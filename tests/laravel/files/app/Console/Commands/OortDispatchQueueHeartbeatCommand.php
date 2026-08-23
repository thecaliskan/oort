<?php

namespace App\Console\Commands;

use App\Jobs\OortQueueHeartbeatJob;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

class OortDispatchQueueHeartbeatCommand extends Command
{
    protected $signature = 'oort:dispatch-queue-heartbeat {--clear : Remove the queue heartbeat before dispatching}';

    protected $description = 'Dispatch the OORT queue heartbeat job for integration tests';

    public function handle(): int
    {
        if ($this->option('clear')) {
            Cache::store('redis')->forget('oort:queue:heartbeat');
        }

        OortQueueHeartbeatJob::dispatch();

        return self::SUCCESS;
    }
}
