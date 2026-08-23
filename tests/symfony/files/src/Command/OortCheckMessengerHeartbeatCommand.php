<?php

namespace App\Command;

use Predis\Client;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

#[AsCommand(
    name: 'oort:check-messenger-heartbeat',
    description: 'Verify the OORT messenger heartbeat message was processed',
)]
final class OortCheckMessengerHeartbeatCommand extends Command
{
    public function execute(InputInterface $input, OutputInterface $output): int
    {
        $redis = new Client($_ENV['REDIS_URL']);
        $heartbeat = $redis->get('oort:messenger:heartbeat');

        if ($heartbeat === null) {
            $output->writeln('<error>Messenger heartbeat not found</error>');

            return Command::FAILURE;
        }

        $output->writeln($heartbeat);

        return Command::SUCCESS;
    }
}
