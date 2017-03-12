Logger Syslog Backend
=====================

Elixir Logger backend for local syslog (and rfc3164).

Requires Erlang 19 since it writes directly to the local syslog Unix Socket (defaults to /dev/log).

## Installation

  1. Add `logger_syslog_backend` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:logger_syslog_backend, github: "pma/logger_syslog_backend"}]
    end
    ```

  2. Configure the Logger backend in config/config.exs:

    ```elixir
    config :logger,
      backends: [:console, {LoggerSyslogBackend, :syslog}]

    config :logger, :syslog,
      app_id: :my_app,
      path: "/dev/log"
    ```
