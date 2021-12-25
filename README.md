# NAME

MojoX::Log::GELF - Non-blocking delivery of log messages in Graylog's GELF format

# SYNOPSIS

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

# DESCRIPTION

A drop-in replacement for [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog).

Delivers log messages over the network with the Graylog GELF protocol,
alongside configurable [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog) for console or file based logging.

Relies on [Mojo::IOLoop](https://metacpan.org/pod/Mojo%3A%3AIOLoop) for non blocking network sockets. When using this
module, an event loop will be started if not already running.

# EVENTS

[MojoX::Log::GELF](https://metacpan.org/pod/MojoX%3A%3ALog%3A%3AGELF) inherits all events from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo%3A%3AEventEmitter) and can emit the following new ones

## error

    $gelf->on(error => sub ($stream, $tx_error) {
      use Data::Printer;
      warn "oh no oh no tx error $tx_error fml";
    });

Emitted upon a socket connection error, or a network communication error

## log

    $gelf->on(log => sub ($gelf, $log_arguments)) {
      $log_arguments->{message} .= ' (Hack The Planet!)';
    });

Emitted upon calls to ["log"](#log). Passed a reference to the log arguments. They may be modified
by the event before continuing to be processed by ["log"](#log).

# METHODS

## new( %args )

The constructor takes the following arguments:

- **host** _optional_

    Default value: machine hostname

    Name of the machine generating the log message.

    Appears in graylog as **source** metadata.

- **gelf\_address** _optional_

    Default value: 127.0.0.1

    Hostname or ip address of the graylog server.

- **gelf\_port** _optional_

    Default value: 12201

- **gelf\_protocol** _optional_

    Default value: tcp

    Accepts values: tcp, udp

    Socket protocol for server connection.

- **gelf\_chunk\_size** _optional_

    Default value: wan

    Accepts values: lan, wan, or integer size in bytes.

    Set value 0 to disable chunking.

- **log\_level** _optional_

    Log messages of less severity will not be transmitted.

- **additional\_fields** _optional_

    Accepts a hashref of metadata to inject in every GELF message.

## is\_level( $log\_level )

Based on configured **log\_level**, returns true if log message
at the given level would be transmitted.

May be given Mojo log levels (trace, fatal) and sylog log levels
(err, emerg). Module makes opinionated decisions how to co-mingle
these differing standards.

## log( %args )

Send log message to a graylog server without blocking.

Returns the id of the log process on the event loop.

Accepts the following arguments:

- **level** _required_

    Accepts a string or integer log severity level.

    Accepts values: trace, debug, info, notice, warn, err, crit, alert,
    emerg, fatal, 0 .. 7

    Log message will be ignored if log level is below the configured min\_level.

- **additional\_fields** _required_

    Accepts hashref metadata attached to the GELF message.

    Where a metadata key name conflicts with metadata configured on the
    object instance, the value passed to this method will be used.

# COMPATABILITY SHORTCUT METHODS

The following methods exist to provide limited interface compability with [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog)

## trace(@messages)

## debug(@messages)

## info(@messages)

## notice(@messages)

## warn(@messages)

## warning(@messages)

## err(@messages)

## error(@messages)

## crit(@messages)

## critical(@messages)

## alert(@messages)

## emerg(@messages)

## emergency(@messages)

## fatal(@messages)

# LICENSE and COPYRIGHT

Copyright 2021 (C) mitch@mjac.dev

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

mjac mitch@mjac.dev

# SEE ALSO

Portions of this module are derivitive of [Log::Dispatch::Gelf](https://metacpan.org/pod/Log%3A%3ADispatch%3A%3AGelf)

See also [Log::GELF::Util](https://metacpan.org/pod/Log%3A%3AGELF%3A%3AUtil), [Mojolicious](https://metacpan.org/pod/Mojolicious), [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog)
