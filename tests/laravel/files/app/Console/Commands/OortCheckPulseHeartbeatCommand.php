<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class OortCheckPulseHeartbeatCommand extends Command
{
    protected $signature = 'oort:check-pulse-heartbeat';

    protected $description = 'Verify the OORT Pulse heartbeat entry was digested into the database';

    public function handle(): int
    {
        $entry = DB::table('pulse_entries')
            ->where('type', 'oort_pulse_heartbeat')
            ->where('key', 'test')
            ->orderByDesc('timestamp')
            ->first();

        if ($entry === null) {
            $this->error('Pulse heartbeat not found');

            return self::FAILURE;
        }

        $this->line((string) $entry->value);

        return self::SUCCESS;
    }
}
