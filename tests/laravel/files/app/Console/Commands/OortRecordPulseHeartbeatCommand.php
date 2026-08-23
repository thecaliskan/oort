<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Laravel\Pulse\Facades\Pulse;

class OortRecordPulseHeartbeatCommand extends Command
{
    protected $signature = 'oort:record-pulse-heartbeat {--clear : Remove prior OORT Pulse heartbeat data}';

    protected $description = 'Record a Pulse entry for OORT integration tests';

    public function handle(): int
    {
        if ($this->option('clear')) {
            DB::table('pulse_entries')->where('type', 'oort_pulse_heartbeat')->delete();
            DB::table('pulse_aggregates')->where('type', 'oort_pulse_heartbeat')->delete();

            $prefix = config('database.redis.options.prefix', '');
            Redis::connection()->del($prefix.'laravel:pulse:ingest');

            return self::SUCCESS;
        }

        $timestamp = time();

        Pulse::record('oort_pulse_heartbeat', 'test', $timestamp)->count();
        Pulse::ingest();

        return self::SUCCESS;
    }
}
