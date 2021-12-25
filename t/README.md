# TESTS

Tests that generate network activity are skipped by default.

These tests can be enabled without needing a listening Graylog server.
By default, the tests transmit UDP packets to localhost on port 12201.
Using UDP, the module doesn't know or care if the packets are actually
delivered, so it's network code can be tested without a server.

## TEST ENVIRONMENT VARIABLES

The following environment variables are used by tests and all optional.
Default values are shown.

- MLG_TESTS_ENABLE_NETWORK=0
- MLG_TESTS_HOST=hostname()
- MLG_TESTS_GELF_ADDRESS=127.0.0.1
- MLG_TESTS_GELF_PORT=12201
- MLG_TESTS_GELF_PROTOCOL=udp
- MLG_TESTS_GELF_CHUNK_SIZE=wan
