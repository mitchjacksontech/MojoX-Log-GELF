use strict;
use warnings;
use Test2::Bundle::More;
use Test2::Tools::Subtest qw/subtest_buffered/;
use MojoX::Log::GELF;

my $log = MojoX::Log::GELF->new;

# default level is debug
cmp_ok($log->min_level, 'eq', 'debug');

# Module has to work with a frankenstein combination of
# syslog log levels for graylog, and ad-hock log levels from Mojo::Log
# These results represent my best guess for how these two should coexist

my %expect = (
  debug => {
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
  },
  info => {
    trace     => 0,
    debug     => 0,
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
    7         => 0,
  },
  error => {
    trace     => 0,
    debug     => 0,
    info      => 0,
    notice    => 0,
    warn      => 0,
    warning   => 0,
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
    4         => 0,
    5         => 0,
    6         => 0,
    7         => 0,
  },
  fatal => {
    trace     => 0,
    debug     => 0,
    info      => 0,
    notice    => 0,
    warn      => 0,
    warning   => 0,
    error     => 0,
    err       => 0,
    crit      => 0,
    critical  => 0,
    alert     => 0,
    emerg     => 1,
    emergency => 1,
    fatal     => 1,
    0         => 1,
    1         => 0,
    2         => 0,
    3         => 0,
    4         => 0,
    5         => 0,
    6         => 0,
    7         => 0,
  },
);

for my $min_level (sort keys %expect) {
  subtest_buffered "min_level_$min_level" => sub {
    ok($log->min_level($min_level), "\$log->min_level($min_level) OK");
    while (my ($ask_level, $expect) = each(%{ $expect{$min_level} })) {
      cmp_ok($log->is_level($ask_level),
        'eq', $expect, "[$min_level] \$log->is_level($ask_level) eq $expect");
      die "f" unless $log->is_level($ask_level) eq $expect;
    }
  }
}

done_testing();
