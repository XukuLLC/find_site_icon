defmodule FindSiteIcon.MixProject do
  use Mix.Project

  @version "0.4.0"
  @url "https://github.com/XukuLLC/find_site_icon"
  @maintainers [
    "Neil Berkman"
  ]

  def project do
    [
      name: "FindSiteIcon",
      app: :find_site_icon,
      version: @version,
      elixir: "~> 1.16.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      source_url: @url,
      maintainers: @maintainers,
      description: "Finds a large icon for a website given a URL.",
      homepage_url: @url,
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ex_doc, "~> 0.32", only: :dev, runtime: false},
      {:meeseeks, "~> 0.17.0"},
      {:meeseeks_html5ever, "~> 0.14.3"},
      {:mock, "~> 0.3.8"},
      {:castore, "~> 1.0.3"},
      {:tesla, "~> 1.9.0"},
      {:mint, "~> 1.6.0"}
    ]
  end

  defp package do
    [
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{github: @url},
      files: ~w(lib) ++ ~w(LICENSE mix.exs README.md)
    ]
  end
end
