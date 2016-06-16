defmodule Eternal do
  use GenServer

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
  5. The `owner` will check to see if the `heir` is alive once a minute in order
    to try and minimise situations where there is no `heir`. Note that this interval
    is configurable.

  This means that there should always be an `heir` to your table, which should
  ensure that you don't lose anything inside ETS.
  """

  # add an alias for Application
  alias Application, as: App

  # require the Logger macros
  require Logger

  # table type
  @type table :: number | atom

  @doc """
  Creates a new ETS table using the provided `ets_opts`.

  These options are passed through as-is, with the exception of prepending the
  `:public` option. Seeing as you can't execute inside the GenServers, your table
  will have to be public to be interacted with.

  The result of the call to `:ets.new/2` is the return value of this function.

  ## Options

  You may provide a third parameter containing Eternal options:

  - `:monitor` - determines which frequency will be used to check the state of
    the `heir` server. It defaults to a minute, and should be set in milliseconds.
    Setting this to `false` will disable this type of monitoring.
  - `:quiet` - by default, Eternal logs debug messages. Setting this to true will
    disable this logging.

  ## Examples

      iex> Eternal.new(:table1)
      126995

      iex> Eternal.new(:table2, [ :named_table ])
      :table2

      iex> Eternal.new(:table3, [ :named_table ], [ quiet: true ])
      :table3

  """
  @spec new(name :: atom, ets_opts :: Keyword.t, opts :: Keyword.t) :: table
  def new(name, ets_opts \\ [], opts \\ [])
  when is_atom(name) and is_list(ets_opts) and is_list(opts) do
    table = :ets.new(name, [ :public ] ++ ets_opts)
    flags = Keyword.take(opts, [ :monitor, :quiet ])

    ensure_started(flags)

    { :ok, pid1 } = GenServer.start(__MODULE__, { table, flags })
    { :ok, pid2 } = GenServer.start(__MODULE__, { table, flags })

    heir(table, pid2)
    gift(table, pid1)

    table
  end

  @doc """
  Returns the heir of a given ETS table.

  ## Examples

      iex> Eternal.heir(:my_table)
      #PID<0.134.0>

  """
  @spec heir(table :: table) :: pid | :undefined
  def heir(table) when is_atom(table) or is_number(table) do
    :ets.info(table, :heir)
  end

  @doc """
  Returns the owner of a given ETS table.

  ## Examples

      iex> Eternal.owner(:my_table)
      #PID<0.132.0>

  """
  @spec owner(table :: table) :: pid | :undefined
  def owner(table) when is_atom(table) or is_number(table) do
    :ets.info(table, :owner)
  end

  @doc """
  Terminates both servers in charge of a given ETS table.

  Note: this will terminate your ETS table.

  ## Examples

      iex> Eternal.terminate(:my_table)
      :ok

  """
  @spec terminate(table :: table) :: :ok
  def terminate(table) when is_atom(table) or is_number(table) do
    stop(owner(table))
    stop(heir(table))
    ets_try(fn ->
      :ets.delete(table)
    end)
  end

  ###
  # Internal GenServer stuff - shouldn't be used externally.
  ###

  # Handles the transfer of an ETS table from an owner to an heir, with the server
  # receiving this message being the heir. We log the change before starting a new
  # heir and triggering a monitor to occur against this server (the new owner).
  def handle_info({ :"ETS-TRANSFER", table, from, reason }, { table, opts } = state) do
    log("Table #{table} #{reason}ed to #{spid(self)} via #{spid(from)}", opts)

    start_heir(table, opts)
    monitor(table, self, opts)

    { :noreply, state }
  end

  # Handles the monitoring of an heir. This is called on an interval using message
  # and a customizable delay. We check to see if the heir is still alive. If so,
  # then we just set another monitor to execute to repeat the check. Otherwise
  # we start up a new heir to make sure that we don't run the risk of dying.
  def handle_info({ :"ETS-HEIR-MONITOR", table }, { table, opts } = state) do
    unless is_pid(heir = heir(table)) && Process.alive?(heir) do
      rescue_heir(state)
    end
    monitor(table, self, opts)
    { :noreply, state }
  end

  # Handles the termination of an heir, through the usual GenServer stop functions.
  # In this scenario the heir will attempt to message through to the owner in order
  # to inform it to create a new heir, which it will then carry out.
  def handle_info({ :"ETS-HEIR-TERMINATE", table }, { table, _opts } = state) do
    rescue_heir(state)
    { :noreply, state }
  end

  # Provides a handle to terminate safely without spinning up new servers.
  def handle_info({ :terminate, :safe_exit }, { _table, opts } = state) do
    log("Received :safe_exit request, terminating...", opts)
    { :stop, { :shutdown, :safe_exit }, state }
  end

  # Attempts to catch termination notifications and forwards a message back to the
  # owner of the table in order to inform it that the heir has died and a new one
  # should be created.
  def terminate({ :shutdown, :safe_exit }, _state), do: nil
  def terminate(_reason, { table, _opts }) do
    if (owner = owner(table)) != :undefined do
      send(owner, { :"ETS-HEIR-TERMINATE", table })
    end
  end

  ###
  # Private utilities for internal use.
  ###

  # Ensure that any required components are started. At this point we just start
  # the Logger if we're in a noisy environment, to avoid users having to do this
  # manually (which is fine normally, but inside slave nodes it's nightmarish).
  defp ensure_started(opts) do
    noisy(opts, fn ->
      App.ensure_all_started(:logger)
    end)
  end

  # Binding for try/rescue to deal with ETS not existing.
  defp ets_try(fun) do
    fun.()
  rescue
    _ -> false
  end

  # Gifts away an ETS table to a given process.
  defp gift(table, pid) do
    ets_try(fn ->
      :ets.give_away(table, pid, :gift)
    end)
  end

  # Sets the heir of an ETS table to a given process.
  defp heir(table, pid) do
    ets_try(fn ->
      :ets.setopts(table, { :heir, pid, :heir })
    end)
  end

  # Determines the interval for a monitor. If the provided value is a positive
  # number, we return it. Otherwise if it's set to false, we return `nil` (which)
  # will cause the monitor to be disabled. For any other value, we return a default
  # value of a minute (1000 * 60 * 60 milliseconds).
  defp interval(value) when is_number(value) and value > 0, do: value
  defp interval(false), do: nil
  defp interval(_vals), do: :timer.minutes(1)

  # Logs a debug message with a project prefix.
  defp log(msg, opts) do
    noisy(opts, fn ->
      Logger.debug("[eternal] #{msg}")
    end)
  end

  # Sets a monitor to execute after a given delay. This is used to refresh the
  # heir server if anything has happened to it.
  defp monitor(table, owner, opts) do
    if time = interval(opts[:monitor]) do
      :erlang.send_after(time, owner, { :"ETS-HEIR-MONITOR", table })
    end
  end

  # Only executes a function if we're in a noisy environment. Basically means that
  # we don't have the `:quiet` flag passed in.
  defp noisy(opts, fun) do
    !Keyword.get(opts, :quiet) && fun.()
    :ok
  end

  # Rescues an heir server by logging out the death, starting a new server, and
  # then logging the process id of the new server handle.
  defp rescue_heir({ table, opts }) do
    log("Heir for #{table} died, starting new server...", opts)
    pid = start_heir(table, opts)
    log("Started new heir #{spid(pid)}", opts)
  end

  # Shorthand for formatting PID as a binary.
  defp spid(pid) do
    inspect(pid)
  end

  # Starts an heir server and sets the server as an heir of the provided table.
  defp start_heir(table, opts) do
    { :ok, pid } = GenServer.start(__MODULE__, { table, opts })
    heir(table, pid)
    pid
  end

  # Stops a given Eternal server using the `:normal` reason.
  defp stop(pid) do
    if is_pid(pid) and Process.alive?(pid) do
      send(pid, { :terminate, :safe_exit })
    else
      :ok
    end
  end

end
