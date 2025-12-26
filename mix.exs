defmodule Fledex.Scheduler.Mixfile do
  use Mix.Project

  @source_url "https://github.com/a_maze_d/fledex_scheduler"
  @version "0.1.0"

  def project do
    [
      app: :fledex_scheduler,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "Fledex_Scheduler",
      test_coverage: [
        tool: ExCoveralls
      ]
    ]
  end

  def application do
    [
      extra_applications: [:crontab, :logger, :tzdata]
    ]
  end

  defp deps do
    [
      {:crontab, "~> 1.2.0"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:tzdata, "~> 1.1", optional: true},
      {:excoveralls, "~> 0.18", only: :test},
      {:castore, "~> 1.0", only: :test}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
        "coveralls.multiple": :test
      ]
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description: "Fledex_Scheduler is a fork of SchedEx, a simple yet deceptively powerful scheduling library for Elixir, adjusted for the use with Fledex",
      files: ["lib", "test", "config", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Matthias Reik"],
      licenses: ["MIT", "Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end
end
