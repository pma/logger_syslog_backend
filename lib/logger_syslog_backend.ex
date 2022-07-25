defmodule LoggerSyslogBackend do
  @moduledoc false

  @behaviour :gen_event
  use Bitwise

  @default_format "[$level] $levelpad$metadata $message"

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_info({:io_reply, _ref, _}, state) do
    {:ok, state}
  end

  def handle_info({:EXIT, socket, :normal}, state) when is_port(socket) do
    {:ok, %{state | socket: nil}}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  ## Helpers

  defp configure(name, opts) do
    state = %{
      name: nil,
      format: nil,
      level: nil,
      metadata: nil,
      socket: nil,
      facility: nil,
      app_id: nil,
      buffer: nil,
      path: nil
    }

    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    format = Keyword.get(opts, :format, @default_format) |> Logger.Formatter.compile()
    level = Keyword.get(opts, :level)
    metadata = Keyword.get(opts, :metadata, [])
    facility = Keyword.get(opts, :facility, :local2) |> facility_code
    app_id = Keyword.get(opts, :app_id)
    buffer = Keyword.get(opts, :buffer)

    path =
      Keyword.get_lazy(opts, :path, fn -> default_path() end) |> IO.iodata_to_binary()
      |> String.to_charlist()

    %{
      state
      | format: format,
        metadata: metadata,
        level: level,
        facility: facility,
        path: path,
        buffer: buffer,
        app_id: app_id
    }
  end

  defp default_path do
    case :os.type() do
      {:unix, :darwin} -> "/var/run/syslog"
      {:unix, :freebsd} -> "/var/run/log"
      {:unix, _} -> "/dev/log"
    end
  end

  defp log_event(_level, _msg, _ts, _md, %{path: nil} = state) do
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, %{path: path, socket: nil, buffer: buffer} = state) do
    case open_socket(path, buffer) do
      {:ok, socket} ->
        log_event(level, msg, ts, md, %{state | socket: socket})

      _ ->
        {:ok, state}
    end
  end

  defp log_event(level, msg, ts, md, state) do
    ansidata = format_event(level, msg, ts, md, state)
    %{facility: facility, app_id: app_id, socket: socket, path: path} = state
    app_id = app_id || Application.get_application(md[:module] || :elixir)

    pre =
      :io_lib.format('<~B>~s ~s ~p: ', [
        facility ||| severity(level),
        timestamp(ts),
        app_id,
        self()
      ])

    :ok = :gen_udp.send(socket, {:local, path}, 0, [pre, ansidata, ?\n])
    {:ok, state}
  end

  defp open_socket(_path, nil) do
    :gen_udp.open(0, [:local])
  end

  defp open_socket(_path, buffer) do
    :gen_udp.open(0, [:local, sndbuf: buffer])
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    Logger.Formatter.format(format, level, msg, ts, Keyword.take(md, metadata))
  end

  defp severity(:debug), do: 7
  defp severity(:info), do: 6
  defp severity(:warn), do: 4
  defp severity(:error), do: 3

  defp facility_code(:local0), do: 16 <<< 3
  defp facility_code(:local1), do: 17 <<< 3
  defp facility_code(:local2), do: 18 <<< 3
  defp facility_code(:local3), do: 19 <<< 3
  defp facility_code(:local4), do: 20 <<< 3
  defp facility_code(:local5), do: 21 <<< 3
  defp facility_code(:local6), do: 22 <<< 3
  defp facility_code(:local7), do: 23 <<< 3

  def timestamp({{_year, month, date}, {hour, minute, second, _}}) do
    mstr =
      elem(
        {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"},
        month - 1
      )

    :io_lib.format("~s ~2..0B ~2..0B:~2..0B:~2..0B", [mstr, date, hour, minute, second])
  end
end
