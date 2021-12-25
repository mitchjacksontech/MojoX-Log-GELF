# Network tests disabled by default
# See t/README.md about enabling these tests
#
# This test expects a failure attempting to connect to a GELF server
# via tcp on localhost port 12201. If op is actually running graylog there,
# test will fail.
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
    gelf_protocol     => 'tcp',
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
    level             => 'error',
    message           => '[t/connection_refused.t] Test error log event',
    additional_fields => {
      filename => 't/connection_refused.t',
    },
  );

  Mojo::IOLoop->stop_gracefully;

  is($error, 'Connection refused', "Connection refused");
}

done_testing;
