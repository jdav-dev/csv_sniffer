defmodule CsvSniffer.MixProject do
  use Mix.Project

  @source_url "https://github.com/doofinder/csv_sniffer"
  @version "0.2.3"

  def project do
    [
      app: :csv_sniffer,
      version: @version,
      elixir: "~> 1.9",
      name: "CsvSniffer",
      description: "An Elixir port of Python's CSV Sniffer. Adapted to doofinder",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
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
      {:ex_doc, "~> 0.21.3", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:credo, "~> 1.2", only: :dev, runtime: false}
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
      organization: "doofinder",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end
end
