use strict;
use warnings;

package MLGTestUtil;
require Exporter;
our @ISA       = qw/Exporter/;
our @EXPORT_OK = qw/config_from_env allow_network_tests/;

sub allow_network_tests {
  return $ENV{MLG_TESTS_ENABLE_NETWORK} || 0;
}

sub config_from_env {
  my %config;
  my @attr = qw/host gelf_address gelf_port gelf_protocol gelf_chunk_size/;
  for my $attr (@attr) {
    my $env_k = 'MLG_TESTS_' . uc($attr);
    if (exists($ENV{$env_k})) {
      $config{$attr} = $ENV{$env_k};
    }
  }
  return %config;
}
