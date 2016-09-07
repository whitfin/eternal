defmodule Eternal.Priv do
  @moduledoc false
  # This module contains code private to the Eternal project, basically just
  # providing utility functions and macros. Nothing too interesting to see here
  # beyond shorthands for common blocks.

  # we need is_table/1
  import Eternal.Table

  # we also need logging
  require Logger

  @doc """
  Provides a safe execution environment for ETS actions.

  If any errors occur inside ETS, we simply return a false value. It should be
  noted that the table is passed through purely as sugar so we can use inline
  anonymous functions.
  """
  @spec ets_try(table :: Table.t, fun :: function) :: any | false
  def ets_try(table, fun) when is_table(table) and is_function(fun, 1) do
    fun.(table)
  rescue
    _ -> false
  end

  @doc """
  Gifts away an ETS table to another process.

  This must be called from within the owning process.
  """
  @spec gift(table :: Table.t, pid :: pid) :: any | false
  def gift(table, pid) when is_table(table) and is_pid(pid),
  do: ets_try(table, &:ets.give_away(&1, pid, :gift))

  @doc """
  Sets the Heir of an ETS table to a given process.

  This must be called from within the owning process.
  """
  @spec heir(table :: Table.t, pid :: pid) :: any | false
  def heir(table, pid) when is_table(table) and is_pid(pid),
  do: ets_try(table, &:ets.setopts(&1, { :heir, pid, :heir }))

  @doc """
  Logs a message inside a noisy environment.

  If the options contains a truthy quiet flag, no logging occurs.
  """
  @spec log(msg :: any, opts :: Keyword.t) :: :ok
  def log(msg, opts) when is_list(opts) do
    noisy(opts, fn ->
      Logger.debug("[eternal] #{msg}")
    end)
  end

  @doc """
  Executes a function only in a noisy environment.

  Noisy environments are determined by the opts having a falsy quiet flag.
  """
  @spec noisy(opts :: Keyword.t, fun :: function) :: :ok
  def noisy(opts, fun) when is_list(opts) and is_function(fun, 0) do
    !Keyword.get(opts, :quiet) && fun.()
    :ok
  end

  @doc """
  Converts a PID to a Binary using `inspect/1`.
  """
  @spec spid(pid :: pid) :: spid :: binary
  def spid(pid), do: inspect(pid)

  @doc """
  Determines if a list of arguments are correctly formed.
  """
  defmacro is_opts(name, ets_opts, opts) do
    quote do
      is_atom(unquote(name)) and
      is_list(unquote(ets_opts)) and
      is_list(unquote(opts))
    end
  end

end
