defmodule Eternal.Table do
  @moduledoc false
  # This module contains functions related to interactions with tables. At the moment
  # this just consists of guard expressions to determine valid tables, and the ability
  # to convert a table identifier to a valid Supervisor name.

  # define a table typespec
  @opaque t :: number | atom

  @doc """
  Converts a table name to a valid Supervisor name.

  Because tables can be integer references, we convert this to an atom only if
  the `create` flag is set to true. Otherwise, we attempt to convert to an existing
  name (as it should have already been created).
  """
  @spec to_name(name :: (number | atom), create :: true | false) :: name :: atom | nil
  def to_name(name, create \\ false)
  def to_name(name, _create) when is_atom(name),
    do: name
  def to_name(name, true) when is_number(name) do
    name
    |> Kernel.to_string
    |> String.to_atom
  end
  def to_name(name, false) when is_number(name) do
    name
    |> Kernel.to_string
    |> String.to_existing_atom
  rescue
    _ -> nil
  end

  @doc """
  Determines whether a value is a table or not. Tables can be either atoms or
  integer values.
  """
  defmacro is_table(val) do
    quote do
      is_atom(unquote(val)) or
      is_integer(unquote(val))
    end
  end
end
