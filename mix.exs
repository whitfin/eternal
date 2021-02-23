defmodule Eternal.Mixfile do
  use Mix.Project

  @url_github "https://github.com/whitfin/eternal"

  def project do
    [
      app: :eternal,
      name: "Eternal",
      description: "Make your ETS tables live forever",
      version: "1.2.2",
      elixir: "~> 1.2",
      deps: deps(),
      docs: docs(),
      package: package(),
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        docs: :docs,
        coveralls: :cover,
        "coveralls.html": :cover,
        "coveralls.travis": :cover
      ]
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", optional: true, only: [:docs]},
      {:excoveralls, "~> 0.5", optional: true, only: [:cover]}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "LICENSE", "README.md"],
      licenses: ["MIT"],
      links: %{"GitHub" => @url_github},
      maintainers: ["Isaac Whitfield"]
    ]
  end

  defp docs do
    [
      extras: ["README.md": [title: "Overview"]],
      main: "readme",
      source_ref: "master",
      source_url: @url_github,
      api_reference: false
    ]
  end
end
