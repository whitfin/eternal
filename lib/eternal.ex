defmodule Eternal do
  @moduledoc """
  This module implements bindings around what should be an eternal ETS table,
  or at least until you decide to terminate it. It works by using "bouncing"
  GenServers which come up as needed to provide an heir for the ETS table. It
  operates as follows:

  1. An ETS table is created with the provided name and options.
  2. Two GenServers are started, an `owner` and an `heir`. The ETS table is gifted
    to the `owner`, and has the `heir` set as the heir.
  3. If the `owner` crashes, the `heir` becomes the owner, and a new GenServer
    is started and assigned the role of `heir`.
  4. If an `heir` dies, we attempt to start a new GenServer and notify the `owner`
    so that they may change the assigned `heir`.

  This means that there should always be an `heir` to your table, which should
  ensure that you don't lose anything inside ETS.
  """

  # import guards
  import Eternal.Table
  import Eternal.Priv

  # alias while we're at it
  alias Eternal.Priv
  alias Eternal.Table
  alias Eternal.Supervisor, as: Sup

  # Return values of `start_link` functions
  @type on_start :: { :ok, pid } | :ignore |
                    { :error, { :already_started, pid } | { :shutdown, term } | term }

  @doc """
  Creates a new ETS table using the provided `ets_opts`.

  These options are passed through as-is, with the exception of prepending the
  `:public` and `:named_table` options. Seeing as you can't execute inside the
  GenServers, your table will have to be public to be interacted with.

  ## Options

  You may provide a third parameter containing Eternal options:

  - `:name` - override the default naming scheme and use a custom name for this
    table. Remember to use this name when calling `stop/1`.
  - `:quiet` - by default, Eternal logs debug messages. Setting this to true will
    disable this logging.

  ## Examples

      iex> Eternal.start_link(:table1)
      { :ok, _pid1 }

      iex> Eternal.start_link(:table2, [ :compressed ])
      { :ok, _pid2 }

      iex> Eternal.start_link(:table3, [ ], [ quiet: true ])
      { :ok, _pid3 }

  """
  @spec start_link(name :: atom, ets_opts :: Keyword.t, opts :: Keyword.t) :: on_start
  def start_link(name, ets_opts \\ [], opts \\ []) when is_opts(name, ets_opts, opts) do
    with { :ok, pid, _table } <- create(name, [ :named_table ] ++ ets_opts, opts) do
      { :ok, pid }
    end
  end

  @doc """
  Functionally equivalent to `start_link/3`, except that the link to the starting
  process is removed after the table is started.

  ## Examples

      iex> Eternal.start(:table1)
      { :ok, _pid1 }

      iex> Eternal.start(:table2, [ :compressed ])
      { :ok, _pid2 }

      iex> Eternal.start(:table3, [ ], [ quiet: true ])
      { :ok, _pid3 }

  """
  @spec start(name :: atom, ets_opts :: Keyword.t, opts :: Keyword.t) :: on_start
  def start(name, ets_opts \\ [], opts \\ []) when is_opts(name, ets_opts, opts) do
    with { :ok, pid } = v <- start_link(name, ets_opts, opts) do
      :erlang.unlink(pid) && v
    end
  end

  @doc """
  Returns the heir of a given ETS table.

  ## Examples

      iex> Eternal.heir(:my_table)
      #PID<0.134.0>

  """
  @spec heir(table :: Table.t) :: pid | :undefined
  def heir(table) when is_table(table),
    do: :ets.info(table, :heir)

  @doc """
  Returns the owner of a given ETS table.

  ## Examples

      iex> Eternal.owner(:my_table)
      #PID<0.132.0>

  """
  @spec owner(table :: Table.t) :: pid | :undefined
  def owner(table) when is_table(table),
    do: :ets.info(table, :owner)

  @doc """
  Terminates both servers in charge of a given ETS table.

  Note: this will terminate your ETS table.

  ## Examples

      iex> Eternal.stop(:my_table)
      :ok

  """
  @spec stop(table :: Table.t) :: :ok
  def stop(table) when is_table(table) do
    name = Table.to_name(table)
    proc = GenServer.whereis(name)

    if proc && Process.alive?(proc) do
      Supervisor.stop(proc)
    end

    :ok
  end

  # Creates a table supervisor with the provided options and nominates the children
  # as owner/heir of the ETS table immediately afterwards. We do this by fetching
  # the children of the supervisor and using the process id to nominate.
  defp create(name, ets_opts, opts) do
    with { :ok, pid, table } = res <- Sup.start_link(name, ets_opts, opts) do
      [ proc1, proc2 ] = Supervisor.which_children(pid)

      { _id1, pid1, :worker, [__MODULE__.Server] } = proc1
      { _id2, pid2, :worker, [__MODULE__.Server] } = proc2

      Priv.heir(table, pid2)
      Priv.gift(table, pid1)

      res
    end
  end
end
