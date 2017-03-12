defmodule LoggerSyslogBackend.Mixfile do
  use Mix.Project

  def project do
    [app: :logger_syslog_backend,
     version: "0.0.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: [:logger, :inets]]
  end

  defp description do
    "Logger backend that writes to a syslog server over UDP."
  end

  defp package do
    [contributors: ["Paulo Almeida"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/pma/logger_syslog_backend"}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    []
  end
end
