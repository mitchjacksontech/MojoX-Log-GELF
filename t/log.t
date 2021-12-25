# Network tests disabled by default
# See t/README.md about enabling these tests
use strict;
use warnings;
use Test2::Bundle::More;
use Mojo::IOLoop;
use MojoX::Log::GELF;

use lib 'lib';
use lib 't/lib';
use MLGTestUtil qw/config_from_env allow_network_tests/;

SKIP: {
  skip 'set $ENV{MLG_TESTS_ENABLE_NETWORK} for network tests'
    unless allow_network_tests();

  # Start an event loop,
  # push a log message onto the loop,
  # wait for it to resolve,
  # evaluate if error occurred using the on error hook

  Mojo::IOLoop->start;

  my %cfg = (config_from_env());
  my $log = MojoX::Log::GELF->new(
    %cfg,
    additional_fields => {
      facility => 'log.t',
    },
  );
  my $error;

  $log->on(
    error => sub {
      my ($stream, $tx_error) = @_;
      $error = $tx_error;
    }
  );

  my $id = $log->log(
    level             => 'info',
    message           => '[t/log.t] Test info log event',
    additional_fields => {
      filename => 't/log.t',
    },
  );

  Mojo::IOLoop->stop_gracefully;

  is($error, undef, "Log event transmitted");

}

done_testing;
