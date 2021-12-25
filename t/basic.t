use strict;
use warnings;
use Test2::Bundle::More;
use MojoX::Log::GELF;

my $log = MojoX::Log::GELF->new;
ok($log, 'Instantiate');
isa_ok($log,           'MojoX::Log::GELF');
isa_ok($log->mojo_log, 'Mojo::Log');

cmp_ok($log->min_level, 'eq', 'debug');
my %expect = (
  trace     => 1,
  debug     => 1,
  info      => 1,
  notice    => 1,
  warn      => 1,
  warning   => 1,
  error     => 1,
  err       => 1,
  crit      => 1,
  critical  => 1,
  alert     => 1,
  emerg     => 1,
  emergency => 1,
  fatal     => 1,
  0         => 1,
  1         => 1,
  2         => 1,
  3         => 1,
  4         => 1,
  5         => 1,
  6         => 1,
  7         => 1,
);

done_testing();
