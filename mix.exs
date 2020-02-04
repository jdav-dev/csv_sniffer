defmodule CsvSniffer.MixProject do
  use Mix.Project

  def project do
    [
      app: :csv_sniffer,
      version: "0.1.0",
      elixir: "~> 1.9",
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
      {:ex_doc, "~> 0.21.3", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "CsvSniffer",
      source_ref: "v#{@version}",
      source_url: "https://github.com/jdav-dev/csv_sniffer"
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/jdav-dev/csv_sniffer"}
    }
  end
end
