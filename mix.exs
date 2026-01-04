# Copyright 2025-2026, Matthias Reik <fledex@reik.org>
# Modified version of : https://github.com/SchedEx/SchedEx
#
# SPDX-License-Identifier: MIT
defmodule Fledex.Scheduler.Mixfile do
  use Mix.Project

  @source_url "https://github.com/a_maze_d/fledex_scheduler"
  @version "0.2.0-dev"

  def project do
    [
      app: :fledex_scheduler,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
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
      {:tzdata, "~> 1.1", optional: true},

      # documentation
      {:ex_doc, "~>0.38", only: :dev, runtime: false},

      # code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_binary_patterns, "~> 0.2.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_check, "~> 0.16.0", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      # required by excoveralls
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
      description:
        "Fledex_Scheduler is a fork of SchedEx, a simple yet deceptively powerful scheduling library for Elixir, adjusted for the use with Fledex",
      files: ["lib", "test", "config", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Matthias Reik"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp dialyzer do
    [
      check_plt: true,
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      incremental: true,
      plt_add_apps: [:mix],
      flags: [
        # :missing_return,
        # :extra_return,
        # :unmatched_returns,
        :error_handling
        # :underspecs
      ]
    ]
  end

  defp aliases do
    [
      reuse: [&run_reuse/1]
    ]
  end

  defp run_reuse(_) do
    {response, exit_status} = System.cmd("pipx", ["run", "reuse", "lint"])
    IO.puts(response)

    case exit_status do
      0 -> :ok
      error -> Mix.raise("Reuse failed with error code: #{error}")
    end
  end
end
