Logger Syslog Backend
=====================

Elixir Logger backend for local syslog (and rfc3164).

Requires Erlang 19 since it writes directly to the local syslog Unix Socket (/dev/log).

## Installation

  1. Add `logger_syslog_backend` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:logger_syslog_backend, "~> 0.0.1"}]
    end
    ```

  2. Configure the Logger backend in config/config.exs:

    ```elixir
    config :logger,
      backends: [:console, {LoggerSyslogBackend, :syslog}]

    config :logger, :syslog,
      app_id: :my_app,  # defaults to the application of the caller module
      path: "/dev/log"  # defaults to "/dev/log" in Linux and "/var/run/syslog" in macOS
    ```
