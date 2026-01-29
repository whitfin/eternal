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

  @doc """
  Starts an Eternal Supervision tree which manages the two internal servers.

  This returns a Tuple containing the table name, so it cannot be used inside a
  Supervision tree directly. If you want to use this Supervisor, you should go
  via the main Eternal module.
  """
  @spec start_link(name :: atom, ets_opts :: list, opts :: Keyword.t()) ::
          {:ok, pid, atom}
          | :ignore
          | {:error, {:already_started, pid} | {:shutdown, term} | term}
  def start_link(name, ets_opts \\ [], opts \\ [])
      when is_opts(name, ets_opts, opts) do
    detect_clash(name, fn ->
      super_tab = :ets.new(name, [:public, :named_table] ++ ets_opts)
      super_args = {super_tab, opts, self()}
      super_opts = [name: Keyword.get_lazy(opts, :name, fn -> super_tab end)]
      super_proc = Supervisor.start_link(__MODULE__, super_args, super_opts)

      with {:ok, pid} <- super_proc do
        {:ok, pid, super_tab}
      end
    end)
  end

  @doc false
  # Main initialization phase which takes a table and options as an argument and
  # sets up a child spec containing the two GenServers, passing through arguments
  # as necessary. We also ensure that the Logger application is started at this
  # point, just in case the user has been unable to start it for some reason.
  @spec init({table :: atom, opts :: Keyword.t(), base :: pid}) :: {:ok, tuple}
  def init({table, opts, base}) do
    flags = Keyword.take(opts, [:monitor, :quiet])

    Priv.noisy(flags, fn ->
      App.ensure_all_started(:logger)
    end)

    [{table, flags, base}]
    |> init_children
    |> init_supervisor
  end

  # Conditionally compile child specifications based on Elixir version.
  if Version.match?(System.version(), ">= 1.5.0") do
    # Creates a child spec using the >= v1.5 Elixir formatting and options.
    defp init_children(arguments),
      do: [
        %{id: Server.One, start: {Eternal.Server, :start_link, arguments}},
        %{id: Server.Two, start: {Eternal.Server, :start_link, arguments}}
      ]

    # Initializes a Supervisor using the >= v1.5 Elixir options.
    defp init_supervisor(children),
      do: Supervisor.init(children, strategy: :one_for_one)
  else
    # Creates a child spec using the < v1.5 Elixir formatting and options.
    defp init_children(arguments),
      do: [
        worker(Eternal.Server, arguments, id: Server.One),
        worker(Eternal.Server, arguments, id: Server.Two)
      ]

    # Initializes a Supervisor using the < v1.5 Elixir options.
    defp init_supervisor(children),
      do: supervise(children, strategy: :one_for_one)
  end

  # Detects a potential name clash inside ETS. We calculate this by looking for
  # the name inside the list of ETS tables. If we have a named table and the
  # table is already in use, we return a link to the existing Supervisor. This
  # means we can be transparent to any crashes caused by starting the same ETS
  # table twice. Otherwise, we execute the callback which will create the table.
  defp detect_clash(name, fun) do
    if Enum.member?(:ets.all(), name) do
      {:error, {:already_started, Process.whereis(name)}}
    else
      fun.()
    end
  end
end
