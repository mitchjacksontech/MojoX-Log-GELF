package MojoX::Log::GELF;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use Carp qw(croak);
use Data::Printer qw();
use Mojo::IOLoop;
use Mojo::Log;
use Log::Gelf::Util qw();
use Sys::Hostname qw(hostname);

use version; our $VERSION = version->declare('v0.0.2');

has 'host'              => sub { return hostname(); };
has 'gelf_address'      => '127.0.0.1';
has 'gelf_port'         => '12201';
has 'gelf_protocol'     => 'udp';
has 'gelf_chunk_size'   => 'wan';
has 'min_level'         => 'debug';
has 'additional_fields' => sub { return {}; };
has 'mojo_log';
has 'mojo_log_parent';

my $GELF_VERSION = '1.1';

# Graylog uses syslog standard log level names and values
# Mojo::Log uses proprietary log level names and values
# These lookups tables facilitate translating between the two when required
my %MOJO_LOG_METHOD_FOR_LEVEL = (
  trace     => 'trace',
  debug     => 'debug',
  info      => 'info',
  notice    => 'info',
  warn      => 'warn',
  warning   => 'warn',
  err       => 'error',
  error     => 'error',
  crit      => 'error',
  critical  => 'error',
  alert     => 'error',
  emerg     => 'error',
  emergency => 'error',
  fatal     => 'fatal',
  0         => 'fatal',
  1         => 'error',
  2         => 'error',
  3         => 'error',
  4         => 'warn',
  5         => 'info',
  6         => 'info',
  7         => 'debug',
);

my %LOG_LEVEL_VALUE = (
  trace     => 7,
  debug     => 7,
  info      => 6,
  notice    => 5,
  warn      => 4,
  warning   => 4,
  err       => 3,
  error     => 3,
  crit      => 2,
  critical  => 2,
  alert     => 1,
  emerg     => 0,
  emergency => 0,
  fatal     => 0,
  map { $_ => $_ } 0 .. 7
);

sub new ($class, @rest) {
  my $self = $class->next::method(@rest);

  unless ($self->mojo_log) {
    $self->mojo_log(Mojo::Log->new(
      level => $MOJO_LOG_METHOD_FOR_LEVEL{ $self->min_level }
    ));
  }

  $self->mojo_log_parent($self->mojo_log);

  return $self;
}

sub is_level ($self, $level) {
  my $min = $LOG_LEVEL_VALUE{ $self->min_level };
  my $chk = $LOG_LEVEL_VALUE{$level} || 0;

  return $chk <= $min ? 1 : 0;
}

sub log ($self, %payload) {
  $self->emit(log => \%payload);

  return unless $self->is_level($payload{level});

  # Handle Mojo::Log array syntax or callback syntax for message string
  # Mojo::Log concatontes an array argument into a single string joined by spaces
  # Mojo::Log executes a callback, only when in the head of the array
  if (ref $payload{message}) {
    my @msgs = ref $payload{message} eq 'ARRAY' ? @{ $payload{message} } : ($payload{message});
    if (ref $msgs[0] eq 'CODE') {
      $msgs[0] = $msgs[0]();
    }
    $payload{message} = join(' ', @msgs);
  }

  # Copy message to Mojo::Log
  my $mojo_method = $MOJO_LOG_METHOD_FOR_LEVEL{ $payload{level} } || 'info';
  $self->mojo_log->$mojo_method("$payload{message}");

  # Transmit message to graylog
  return $self->_tx_message($self->_prepare_message(\%payload));
}

sub _prepare_message ($self, $payload) {

  # Translate incoming log level into syslog integer,
  # to simulteneously support standard and mojo log level names
  my $level = $LOG_LEVEL_VALUE{ $payload->{level} };
  croak "Unsupported log level: $payload->{level}" unless defined $level;

  (my $short_message = $payload->{short_message} || "$payload->{message}") =~ s/\n.*//s;

  # Combine addl fields from object config and from payload
  my %additional_fields;
  while (my ($k, $v) = each(%{ $self->additional_fields })) {
    $additional_fields{"_${k}"} = $v;
  }
  if ($payload->{additional_fields}) {
    no warnings 'uninitialized';
    while (my ($k, $v) = each(%{ $payload->{additional_fields} })) {
      $additional_fields{"_${k}"} = "$v";
    }
  }

  # Expect crash if validation of message object fails
  return Log::GELF::Util::encode({
    version       => $GELF_VERSION,
    host          => $self->host,
    level         => $level,
    short_message => $short_message,
    full_message  => "$payload->{message}",
    %additional_fields,
  });
}

sub dump ($self, $dump) {
  return unless $self->is_level(7);

  my @caller = caller();
  $self->debug("dump:$caller[0]:$caller[2]");

  Data::Printer::p($dump);
}

sub _tx_message ($self, $gelf_message) {
  my %socket = (
    address        => $self->gelf_address,
    port           => $self->gelf_port,
    socket_options => {
      Proto => $self->gelf_protocol,
    },
  );

  my $id = Mojo::IOLoop->client(
    \%socket => sub ($loop, $socket_error, $stream) {

      if ($socket_error) {
        $self->_handle_error($socket_error);
        return;
      }

      $stream->on(
        error => sub ($stream, $tx_error) {
          $self->_handle_error($tx_error);
        }
      );

      my $chunk_size   = Log::GELF::Util::parse_size($self->gelf_chunk_size);
      my $chunk_append = $self->gelf_protocol ne 'udp' ? "\x00" : '';
      for my $chunk (Log::GELF::Util::enchunk($gelf_message, $chunk_size)) {
        $stream->write($chunk . $chunk_append);
      }

      $stream->close_gracefully;
    },
  );

  unless (Mojo::IOLoop->is_running) {
    Mojo::IOLoop->start;
  }

  return $id;
}

sub _handle_error ($self, $error) {
  if ($self->has_subscribers('error')) {
    $self->emit(error => $error);
  }
  else {
    # Borrow Mojo::Log to surface this error where it might be seen
    $self->mojo_log->context('[' . caller() . ']')->fatal($error);
  }
}

# logging methods for Mojo::Log compatibility
sub trace     ($self, @msg) { return $self->_short_log('trace',     @msg); }
sub debug     ($self, @msg) { return $self->_short_log('debug',     @msg); }
sub info      ($self, @msg) { return $self->_short_log('info',      @msg); }
sub notice    ($self, @msg) { return $self->_short_log('notice',    @msg); }
sub warn      ($self, @msg) { return $self->_short_log('warn',      @msg); }
sub warning   ($self, @msg) { return $self->_short_log('warning',   @msg); }
sub err       ($self, @msg) { return $self->_short_log('err',       @msg); }
sub error     ($self, @msg) { return $self->_short_log('error',     @msg); }
sub crit      ($self, @msg) { return $self->_short_log('crit',      @msg); }
sub critical  ($self, @msg) { return $self->_short_log('critical',  @msg); }
sub alert     ($self, @msg) { return $self->_short_log('alert',     @msg); }
sub emerg     ($self, @msg) { return $self->_short_log('emerg',     @msg); }
sub emergency ($self, @msg) { return $self->_short_log('emergency', @msg); }
sub fatal     ($self, @msg) { return $self->_short_log('fatal',     @msg); }

sub _short_log ($self, $level, @msg) {
  return $self->log(
    level   => $level,
    message => \@msg,
  );
}

# Proxy methods to access Mojo::Log attributes and methods
sub color            ($self, @args) { return $self->mojo_log->color(@args); }
sub format           ($self, @args) { return $self->mojo_log->format(@args); }
sub handle           ($self, @args) { return $self->mojo_log->handle(@args); }
sub history          ($self, @args) { return $self->mojo_log->history(@args); }
sub level            ($self, @args) { return $self->mojo_log->level(@args); }
sub max_history_size ($self, @args) { return $self->mojo_log->max_history_size(@args); }
sub path             ($self, @args) { return $self->mojo_log->path(@args); }
sub short            ($self, @args) { return $self->mojo_log->short(@args); }
sub append           ($self, @args) { return $self->mojo_log->append(@args); }

sub context ($self, @context) {

  # Emulating, but not fully implementing context functionalty here...
  # Contexts are only one level deep

  $self->mojo_log(Mojo::Log->new(
    parent  => $self->mojo_log_parent,
    context => \@context,
    level   => $self->mojo_log_parent->level,
  ));

  return $self;
}

1;

__END__

=head1 NAME

MojoX::Log::GELF - Non-blocking delivery of log messages in Graylog's GELF format

=head1 SYNOPSIS

  my $log = MojoX::Log::GELF->new(
    host              => 'myserver.example.com',
    gelf_address      => 'logs.example.com',
    gelf_protocol     => 'udp',
    min_level         => 'info',
    additional_fields => {
      facility => 'MyApplication',
      version  => $VERSION,
    },
  );

  # Replace a Mojo app's default log, preserving the original logger
  # and it's configuration
  $app->log(MojoX::Log::GELF->new(
    mojo_log => $app->log,
  ));

  # Log message using Log::Dispatch::Gelf style syntax
  # attaching additional metadata
  $log->log(
    message => 'The dev team is out of coffee!',
    level   => 'emerg',
    additional_fields => {
      brew_method    => 'french_press',
      cups_required  => 6 * 4,
      cups_available => 0,
    },
  );
  #

  # Log message using Mojo::Log syntax
  $log->debug('[context]', 'log message');

  # Log message using Mojo::Log callback syntax
  $log->debug(sub { expensive_sub_to_generate_log_message() });

=head1 DESCRIPTION

A drop-in replacement for L<Mojo::Log>.

Delivers log messages over the network with the Graylog GELF protocol,
alongside configurable L<Mojo::Log> for console or file based logging.

Relies on L<Mojo::IOLoop> for non blocking network sockets. When using this
module, an event loop will be started if not already running.

=head1 EVENTS

L<MojoX::Log::GELF> inherits all events from L<Mojo::EventEmitter> and can emit the following new ones

=head2 error

  $gelf->on(error => sub ($stream, $tx_error) {
    use Data::Printer;
    warn "oh no oh no tx error $tx_error fml";
  });

Emitted upon a socket connection error, or a network communication error

=head2 log

  $gelf->on(log => sub ($gelf, $log_arguments)) {
    $log_arguments->{message} .= ' (Hack The Planet!)';
  });

Emitted upon calls to L</log>. Passed a reference to the log arguments. They may be modified
by the event before continuing to be processed by L</log>.

=head1 METHODS

=head2 new( %args )

The constructor takes the following arguments:

=over

=item B<host> I<optional>

Default value: machine hostname

Name of the machine generating the log message.

Appears in graylog as B<source> metadata.

=item B<gelf_address> I<optional>

Default value: 127.0.0.1

Hostname or ip address of the graylog server.

=item B<gelf_port> I<optional>

Default value: 12201

=item B<gelf_protocol> I<optional>

Default value: tcp

Accepts values: tcp, udp

Socket protocol for server connection.

=item B<gelf_chunk_size> I<optional>

Default value: wan

Accepts values: lan, wan, or integer size in bytes.

Set value 0 to disable chunking.

=item B<log_level> I<optional>

Log messages of less severity will not be transmitted.

=item B<additional_fields> I<optional>

Accepts a hashref of metadata to inject in every GELF message.

=back

=head2 is_level( $log_level )

Based on configured B<log_level>, returns true if log message
at the given level would be transmitted.

May be given Mojo log levels (trace, fatal) and sylog log levels
(err, emerg). Module makes opinionated decisions how to co-mingle
these differing standards.

=head2 log( %args )

Send log message to a graylog server without blocking.

Returns the id of the log process on the event loop.

Accepts the following arguments:

=over 4

=item B<level> I<required>

Accepts a string or integer log severity level.

Accepts values: trace, debug, info, notice, warn, err, crit, alert,
emerg, fatal, 0 .. 7

Log message will be ignored if log level is below the configured min_level.

=item B<additional_fields> I<required>

Accepts hashref metadata attached to the GELF message.

Where a metadata key name conflicts with metadata configured on the
object instance, the value passed to this method will be used.

=back

=head1 COMPATABILITY SHORTCUT METHODS

The following methods exist to provide limited interface compability with L<Mojo::Log>

=head2 trace(@messages)

=head2 debug(@messages)

=head2 info(@messages)

=head2 notice(@messages)

=head2 warn(@messages)

=head2 warning(@messages)

=head2 err(@messages)

=head2 error(@messages)

=head2 crit(@messages)

=head2 critical(@messages)

=head2 alert(@messages)

=head2 emerg(@messages)

=head2 emergency(@messages)

=head2 fatal(@messages)

=head1 LICENSE and COPYRIGHT

Copyright 2021 (C) mitch@mjac.dev

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

mjac mitch@mjac.dev

=head1 SEE ALSO

Portions of this module are derivitive of L<Log::Dispatch::Gelf>

See also L<Log::GELF::Util>, L<Mojolicious>, L<Mojo::Log>

=cut
