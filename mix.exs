defmodule Showcase.MixProject do
  use Mix.Project

  def project do
    [
      app: :showcase,
      version: "0.1.0",
      elixir: "~> 1.14.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      # compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Showcase.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.0-rc.0", override: true},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.3"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_view, "~> 2.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.0"},
      {:timex, "~> 3.7"},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:exconstructor, "~> 1.2.4"},
      {:tesla, "~> 1.4.4"},
      {:recase, "~> 0.7.0"},
      {:exsync, "~> 0.2.4", only: :dev},
      {:elixir_uuid, "~> 1.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm install"],
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
