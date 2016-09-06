defmodule Eternal.Supervisor do
  @moduledoc false
  # This module contains the main Eternal Supervisor which is used to manage the
  # two internal GenServers which act as owner/heir to the ETS table. There's little
  # in here beyond setting up a Supervision tree, as we want to keep the code simple
  # to make it pretty bulletproof as an implementation.

  # this is a supervisor
  use Supervisor

  # we need some guards
  import Eternal.Priv

  # add alias for convenience
  alias Application, as: App
  alias Eternal.Priv
  alias Eternal.Table

  @doc """
  Starts an Eternal Supervision tree which manages the two internal servers.

  This returns a Tuple containing the table name, so it cannot be used inside a
  Supervision tree directly. If you want to use this Supervisor, you should go
  via the main Eternal module.
  """
  @spec start_link(name :: atom, ets_opts :: Keyword.t, opts :: Keyword.t) ::
        { :ok, pid, Table.t } | :ignore |
        { :error, { :already_started, pid } | { :shutdown, term } | term }
  def start_link(name, ets_opts \\ [], opts \\ []) when is_opts(name, ets_opts, opts) do
    super_tab  = :ets.new(name, [ :public ] ++ ets_opts)
    super_args = { super_tab, opts, self() }
    super_opts = [ name: Table.to_name(super_tab, true) ]
    super_proc = Supervisor.start_link(__MODULE__, super_args, super_opts)

    Priv.exec_with { :ok, pid }, super_proc do
      { :ok, pid, super_tab }
    end
  end

  @doc false
  # Main initialization phase which takes a table and options as an argument and
  # sets up a child spec containing the two GenServers, passing through arguments
  # as necessary. We also ensure that the Logger application is started at this
  # point, just in case the user has been unable to start it for some reason.
  @spec init({ table :: Table.t, opts :: Keyword.t }) :: { :ok, tuple }
  def init({ table, opts, base }) do
    flags = Keyword.take(opts, [ :monitor, :quiet ])

    Priv.noisy(flags, fn ->
      App.ensure_all_started(:logger)
    end)

    children = [
      worker(Eternal.Server, [{ table, flags, base }], id: Server.One),
      worker(Eternal.Server, [{ table, flags, base }], id: Server.Two)
    ]

    supervise(children, strategy: :one_for_one)
  end

end
