defmodule Eternal.Server do
  @moduledoc false
  # This module remains internal to Eternal and should not be manually created
  # by anyone external so it shall remain undocumented for now.
  #
  # Basically, this module implements an extremely base GenServer which listens
  # on two messages - the first is that of ETS to trigger a log that the table
  # owner has changed, and the other is a recognisation that a new heir has been
  # attached and needs assigning to ETS (as only an owner can set the heir).

  # use default server behaviour
  use GenServer

  # add a Priv alias
  alias Eternal.Priv

  @doc """
  Simply performs a base validation and passes through the arguments to the server.
  """
  def start_link({ _table, _opts, _base } = args),
    do: GenServer.start_link(__MODULE__, args)

  @doc """
  Initialization phase of an Eternal server.

  If the server process is intended to be a new heir, we message the owner in order
  to let it know we need adding as an heir. We don't do this is there is no owner
  or the owner is the base process creating the Eternal table, as this would result
  in no heir being assigned.
  """
  def init({ table, opts, base }) do
    owner = Eternal.owner(table)

    unless owner in [ :undefined, base ] do
      send(owner, { :"ETS-HEIR-UP", table, self() })
    end

    { :ok, { table, opts } }
  end

  # Handles the transfer of an ETS table from an owner to an heir, with the server
  # receiving this message being the heir. We log the change before starting a new
  # heir and triggering a monitor to occur against this server (the new owner).
  def handle_info({ :"ETS-TRANSFER", table, from, reason }, { table, opts } = state) do
    Priv.log("Table '#{table}' #{reason}ed to #{Priv.spid(self())} via #{Priv.spid(from)}", opts)
    { :noreply, state }
  end

  # Handles the termination of an heir, through the usual GenServer stop functions.
  # In this scenario the heir will attempt to message through to the owner in order
  # to inform it to create a new heir, which it will then carry out.
  def handle_info({ :"ETS-HEIR-UP", table, pid }, { table, opts } = state) do
    Priv.heir(table, pid)
    Priv.log("Assigned new heir #{Priv.spid(pid)}", opts)
    { :noreply, state }
  end

  # Catch all info handler to ensure that we don't crash for whatever reason when
  # an unrecognised message is sent. In theory, a crash shouldn't be an issue, but
  # it's better logically to avoid doing so here.
  def handle_info(_msg, state),
    do: { :noreply, state }
end
