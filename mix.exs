defmodule Eternal.Mixfile do
  use Mix.Project

  @url_docs "http://hexdocs.pm/eternal"
  @url_github "https://github.com/whitfin/eternal"

  def project do
    [
      app: :eternal,
      name: "Eternal",
      description: "Make your ETS tables live forever",
      package: %{
        files: [
          "lib",
          "mix.exs",
          "LICENSE",
          "README.md"
        ],
        licenses: [ "MIT" ],
        links: %{
          "Docs" => @url_docs,
          "GitHub" => @url_github
        },
        maintainers: [ "Isaac Whitfield" ]
      },
      version: "1.2.2",
      elixir: "~> 1.2",
      deps: deps(),
      docs: [
        extras: [ "README.md" ],
        source_ref: "master",
        source_url: @url_github
      ],
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

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      { :ex_doc, "~> 0.16", optional: true, only: [ :docs ] },
      { :excoveralls, "~> 0.5", optional: true, only: [ :cover ] }
    ]
  end
end
