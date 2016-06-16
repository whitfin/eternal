# Eternal
[![Build Status](https://img.shields.io/travis/zackehh/eternal.svg)](https://travis-ci.org/zackehh/eternal) [![Coverage Status](https://img.shields.io/coveralls/zackehh/cachex.svg)](https://coveralls.io/github/zackehh/cachex) [![Hex.pm Version](https://img.shields.io/hexpm/v/eternal.svg)](https://hex.pm/packages/eternal) [![Documentation](https://img.shields.io/badge/docs-latest-yellowgreen.svg)](https://hexdocs.pm/eternal/)

Eternal is a simple way to monitor an ETS table to ensure that it never dies. It works by using bouncing GenServers to ensure that both an owner and heir are always available, via the use of scheduled monitoring and message passing. The idea is similar to that of the Immortal library, but taking it further to ensure a more bulletproof solution - and removing the need to have a single process dedicated to owning your ETS table.

## Installation

Eternal is available on [Hex](https://hex.pm/). You can install the package via:

  1. Add eternal to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:eternal, "~> 1.0.2"}]
    end
    ```

  2. Ensure eternal is started before your application:

    ```elixir
    def application do
      [applications: [:eternal]]
    end
    ```

## Usage

The API of Eternal is quite small in order to reduce the risk of potential crashes (as that would cause you to lose your ETS tables). The main function you need is simply `Eternal.new/3`, which behaves in a similar way to `:ets.new/2`. The first two arguments are identical to `:ets.new/2`, and the latter is just a Keyword List of options to configure Eternal (this argument is optional).

```elixir
iex> Eternal.new(:table_name, [ :set, { :read_concurrency, true }])
126995
iex> Eternal.new(:table_name, [ :named_table, :set, { :read_concurrency, true }])
:table_name
```

The returned value is the id of your ETS table (remember if you want the name, you have to provide the `:named_table` option). You can use this returned value to interact safely with ETS, and Eternal will monitor your table in the background.

For further usage examples, please see the [documentation](https://hexdocs.pm/eternal/).

## Contributions

If you feel something can be improved, or have any questions about certain behaviours or pieces of implementation, please feel free to file an issue. Proposed changes should be taken to issues before any PRs to avoid wasting time on code which might not be merged upstream.

## Credits

Thanks to the following for the inspiration for this project:

- [Daniel Berkompas](https://github.com/danielberkompas/immortal)
- [Steve Vinoski](http://steve.vinoski.net/blog/2011/03/23/dont-lose-your-ets-tables/)
