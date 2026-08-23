<?php

namespace App\Command;

use Predis\Client;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

#[AsCommand(
    name: 'oort:scheduler-heartbeat',
    description: 'Manage the OORT scheduler heartbeat for integration tests',
)]
final class OortSchedulerHeartbeatCommand extends Command
{
    protected function configure(): void
    {
        $this->addOption('clear', null, InputOption::VALUE_NONE, 'Remove the scheduler heartbeat');
    }

    public function execute(InputInterface $input, OutputInterface $output): int
    {
        if ($input->getOption('clear')) {
            $redis = new Client($_ENV['REDIS_URL']);
            $redis->del('oort:scheduler:heartbeat');

            return Command::SUCCESS;
        }

        $output->writeln('<error>Use --clear to remove the scheduler heartbeat</error>');

        return Command::FAILURE;
    }
}
