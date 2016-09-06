# Eternal
[![Build Status](https://img.shields.io/travis/zackehh/eternal.svg)](https://travis-ci.org/zackehh/eternal) [![Coverage Status](https://img.shields.io/coveralls/zackehh/cachex.svg)](https://coveralls.io/github/zackehh/cachex) [![Hex.pm Version](https://img.shields.io/hexpm/v/eternal.svg)](https://hex.pm/packages/eternal) [![Documentation](https://img.shields.io/badge/docs-latest-yellowgreen.svg)](https://hexdocs.pm/eternal/)

Eternal is a simple way to monitor an ETS table to ensure that it never dies. It works by using bouncing GenServers to ensure that both an owner and heir are always available, via the use of scheduled monitoring and message passing. The idea is similar to that of the Immortal library, but taking it further to ensure a more bulletproof solution - and removing the need to have a single process dedicated to owning your ETS table.

## Installation

Eternal is available on [Hex](https://hex.pm/). You can install the package via:

  1. Add eternal to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:eternal, "~> 1.1"}]
    end
    ```

  2. Ensure eternal is started before your application:

    ```elixir
    def application do
      [applications: [:eternal]]
    end
    ```

## Usage

### Manual Startup

The API of Eternal is quite small in order to reduce the risk of potential crashes (as that would cause you to lose your ETS tables). You'll probably just want to use `start_link/3` which behaves quite similarly to `:ets.new/2`. The first two arguments are identical to `:ets.new/2`, and the latter is just a Keyword List of options to configure Eternal.

It should be noted that the table will always have the `:public` (for table access) and `:named_table` (for table naming) arguments passed in, whether specified or not. Both the second and third arguments are optional.

```elixir
iex> Eternal.start_link(:table1, [ :set, { :read_concurrency, true }])
{ :ok, #PID<0.402.0> }
iex> Eternal.start_link(:table2, [ :set, { :read_concurrency, true }], [ quiet: true ])
{ :ok, #PID<0.406.0> }
```

For further usage examples, please see the [documentation](https://hexdocs.pm/eternal/).

### Application Supervision

I'd highly recommend setting up an Application and letting Eternal start up inside the Supervision tree this way - just make sure that your strategy is `:one_for_one`, otherwise a crash in a different child in the tree would restart your ETS table.

```elixir
defmodule MyApplication do
  # define application
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Eternal, [:table, [ :compressed ], [ quiet: true ]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [ strategy: :one_for_one ]
    Supervisor.start_link(children, opts)
  end
end
```

If you need a strategy other than `:one_for_one` (which is rare), you can simply hoist Eternal to a tree above your main application tree. This is a little more complicated, but ensures your tables are safe. You can do this using something like the following (you can see how Eternal is distanced from your app logic which may cause a restart):

```elixir
defmodule MyApplication do
  # define application
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Note how we create our main application tree separately to our Eternal
    # tree, thus making Eternal resistant to crashes around your application.
    children = [
      supervisor(Eternal, [:table, [ :compressed ], [ quiet: true ]]),
      supervisor(Supervisor, [MyApplication.OneForAllSupervisor, [ ]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [ strategy: :one_for_one ]
    Supervisor.start_link(children, opts)
  end
end

defmodule MyApplication.OneForAllSupervisor do
  use Supervisor

  def init([]) do
    children = [ worker(MyModuleWhichMightCrash, []) ]
    supervise(children, strategy: :one_for_all)
  end
end
```

## Contributions

If you feel something can be improved, or have any questions about certain behaviours or pieces of implementation, please feel free to file an issue. Proposed changes should be taken to issues before any PRs to avoid wasting time on code which might not be merged upstream.

## Credits

Thanks to the following for the inspiration for this project:

- [Daniel Berkompas](https://github.com/danielberkompas/immortal)
- [Steve Vinoski](http://steve.vinoski.net/blog/2011/03/23/dont-lose-your-ets-tables/)
