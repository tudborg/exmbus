defmodule Exmbus.MixProject do
  use Mix.Project

  @version "0.3.3"
  @source_url "https://github.com/tudborg/exmbus"

  def project do
    [
      app: :exmbus,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description: description(),
      package: package(),

      # docs
      name: "Exmbus",
      docs: &docs/0,

      # Tests
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp dialyzer do
    [plt_add_apps: [:nimble_csv, :crypto]]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Henrik Tudborg"],
      links: %{"GitHub" => @source_url},
      files: ~w(mix.exs README.md CHANGELOG.md lib priv)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp description() do
    """
    M-Bus & Wireless M-Bus (wM-bus) parser library
    """
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_coverage() do
    [
      ignore_modules: [
        Exmbus.Parser.TableLoader.TableCSV
      ],
      summary: [
        threshold: 50
      ]
    ]
  end

  defp aliases do
    []
  end

  defp deps do
    [
      # development and test dependencies
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # compile dependencies
      {:nimble_csv, "~> 1.1", runtime: false},
      # dependencies
      {:crc, "~> 0.10.1"}
    ]
  end
end
