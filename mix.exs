defmodule Exmbus.MixProject do
  use Mix.Project

  def project do
    [
      app: :exmbus,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: test_coverage()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  def test_coverage() do
    [
      ignore_modules: [
        Exmbus.Parser.TableLoader.TableCSV
      ],
      summary: [
        threshold: 50
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # development and test dependencies
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      # dependencies
      {:nimble_csv, "~> 1.1"},
      {:crc, "~> 0.10.1"}
    ]
  end
end
