<?php

namespace App\Task;

use Symfony\Component\Scheduler\Attribute\AsPeriodicTask;

#[AsPeriodicTask(frequency: '1 hour')]
final class CleanupOldRecords
{
    public function __invoke(): void
    {
    }
}
