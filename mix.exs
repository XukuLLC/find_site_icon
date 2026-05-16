defmodule FindSiteIcon.MixProject do
  @moduledoc false
  use Mix.Project

  @version "1.0.1"
  @url "https://github.com/XukuLLC/find_site_icon"
  @maintainers [
    "Neil Berkman"
  ]

  def project do
    [
      name: "FindSiteIcon",
      app: :find_site_icon,
      version: @version,
      elixir: "~> 1.17 or ~> 1.18 or ~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      source_url: @url,
      maintainers: @maintainers,
      description: "Finds a large icon for a website given a URL.",
      homepage_url: @url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {FindSiteIcon.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:meeseeks, "~> 0.18"},
      {:meeseeks_html5ever, "~> 0.15"},
      {:bypass, "~> 2.1", only: :test},
      {:mock, "~> 0.3", only: :test},
      {:mix_test_watch, "~> 1.4", only: :dev, runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false},
      {:req, "~> 0.5"}
    ]
  end

  defp aliases do
    [
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "test"
      ]
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @url,
      groups_for_extras: [
        Changelog: ~r/CHANGELOG\.md/
      ]
    ]
  end

  defp package do
    [
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/find_site_icon/changelog.html",
        "GitHub" => @url
      },
      files: ~w(lib) ++ ~w(CHANGELOG.md LICENSE mix.exs README.md)
    ]
  end
end
