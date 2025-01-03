defmodule CsvSniffer.MixProject do
  use Mix.Project

  @source_url "https://github.com/jdav-dev/csv_sniffer"
  @version "0.2.2"

  def project do
    [
      app: :csv_sniffer,
      version: @version,
      elixir: "~> 1.9",
      name: "CsvSniffer",
      description: "An Elixir port of Python's CSV Sniffer.",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [credo: :test, dialyzer: :test]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.36.1", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "CsvSniffer",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end
end
