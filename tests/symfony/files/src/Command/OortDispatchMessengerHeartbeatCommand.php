<?php

namespace App\Command;

use App\Message\OortMessengerHeartbeatMessage;
use Predis\Client;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Messenger\MessageBusInterface;

#[AsCommand(
    name: 'oort:dispatch-messenger-heartbeat',
    description: 'Dispatch the OORT messenger heartbeat message for integration tests',
)]
final class OortDispatchMessengerHeartbeatCommand extends Command
{
    public function __construct(private readonly MessageBusInterface $bus)
    {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption('clear', null, InputOption::VALUE_NONE, 'Remove the messenger heartbeat');
    }

    public function execute(InputInterface $input, OutputInterface $output): int
    {
        if ($input->getOption('clear')) {
            $redis = new Client($_ENV['REDIS_URL']);
            $redis->del('oort:messenger:heartbeat');

            return Command::SUCCESS;
        }

        $this->bus->dispatch(new OortMessengerHeartbeatMessage());

        return Command::SUCCESS;
    }
}
