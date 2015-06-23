defmodule LoggerSyslogBackend do
  @moduledoc false

  use GenEvent
  use Bitwise

  @syslog_version 1

  def init(_) do
    case :gen_udp.open(0) do
      {:ok, socket} ->
        {:ok, configure([socket: socket])}
      _ ->
        {:error, :ignore}
    end
  end

  def handle_call({:configure, options}, _state) do
    {:ok, :ok, configure(options)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  ## Helpers

  defp configure(options) do
    env = Application.get_env(:logger, :syslog, [])
    syslog = configure_merge(env, options)
    Application.put_env(:logger, :syslog, syslog)

    format = syslog
    |> Keyword.get(:format)
    |> Logger.Formatter.compile

    level    = Keyword.get(syslog, :level)
    metadata = Keyword.get(syslog, :metadata, [])
    host     = Keyword.get(syslog, :host, '127.0.0.1') |> IO.iodata_to_binary |> String.to_char_list
    port     = Keyword.get(syslog, :port, 514)
    facility = Keyword.get(syslog, :facility, :local2) |> facility_code
    app      = Keyword.get(syslog, :app, :elixir)
    socket   = Keyword.get(options, :socket)
    {:ok, hostname} = :inet.gethostname()
    %{format: format, metadata: metadata, level: level, socket: socket,
      host: host, port: port, facility: facility, app: app,
      hostname: hostname}
  end

  defp configure_merge(env, options) do
    Keyword.merge(env, options)
  end

  defp log_event(level, msg, ts, md, state) do
    ansidata = format_event(level, msg, ts, md, state)

    %{facility: facility, app: app, hostname: hostname, host: host, port: port, socket: socket} = state

    pre = :io_lib.format('<~B>~B ~s ~s ~s ~p ~s - ', [facility ||| severity(level),
                                                      @syslog_version, iso8601_timestamp(), hostname, app, self,
                                                      '-'])

    :gen_udp.send(socket, host, port, [pre, ansidata, ?\n])
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))
  end

  defp severity(:debug), do: 7
  defp severity(:info),  do: 6
  defp severity(:warn),  do: 4
  defp severity(:error), do: 3
  defp severity(_),      do: 7

  defp facility_code(:local0), do: (16 <<< 3)
  defp facility_code(:local1), do: (17 <<< 3)
  defp facility_code(:local2), do: (18 <<< 3)
  defp facility_code(:local3), do: (19 <<< 3)
  defp facility_code(:local4), do: (20 <<< 3)
  defp facility_code(:local5), do: (21 <<< 3)
  defp facility_code(:local6), do: (22 <<< 3)
  defp facility_code(:local7), do: (23 <<< 3)

  defp iso8601_timestamp() do
    {_, _, micro} = now = :os.timestamp()
    {{year, month, day},{hour, minute, second}} = :calendar.now_to_datetime(now)
    format = '~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.~6.10.0BZ'
    :io_lib.format(format, [year, month, day, hour, minute, second, micro])
  end
end
