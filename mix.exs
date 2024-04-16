defmodule Rephex.MixProject do
  use Mix.Project

  def project do
    [
      app: :rephex,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      source_url: "https://github.com/sankaku-deltalab/rephex",
      homepage_url: "https://github.com/sankaku-deltalab/rephex",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.5"},
      {:phoenix_live_view, "~> 0.20.2"},
      {:mox, "~> 1.1", only: [:dev, :test]},
      {:propcheck, "~> 1.4", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Redux-toolkit in Phenix LiveView"
  end

  defp package do
    [
      contributors: ["Sankaku <sankaku_dlt.45631@outlook.jp>"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sankaku-deltalab/rephex"}
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/logo.svg",
      assets: "assets",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
