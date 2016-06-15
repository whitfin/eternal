defmodule EternalTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  test "starting a table with no options" do
    tab = Eternal.new(:table, [], [ quiet: true ])

    on_exit(fn ->
      Eternal.terminate(tab)
    end)

    assert(is_number(tab))
  end

  test "starting a table with options" do
    assert(create(__MODULE__, [ :named_table ]) == __MODULE__)
  end

  test "recovering from a terminated owner" do
    tab = create(:recover_terminated_owner)

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    GenServer.stop(owner)

    :timer.sleep(5)

    assert(is_pid(owner))
    assert(owner != Eternal.owner(tab))
    assert(is_pid(heir))
    assert(heir != Eternal.heir(tab))
  end

  test "recovering from a terminated heir" do
    tab = create(:recover_terminated_heir)

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    GenServer.stop(heir)

    :timer.sleep(5)

    assert(owner == Eternal.owner(tab))
    assert(is_pid(heir))
    assert(heir != Eternal.heir(tab))
  end

  test "recovering from a killed heir" do
    tab = create(:recover_killed_heir, [], [ monitor: 50 ])

    :timer.sleep(250)

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    Process.exit(heir, :kill)

    :timer.sleep(250)

    assert(owner == Eternal.owner(tab))
    assert(is_pid(heir))
    assert(heir != Eternal.heir(tab))
  end

  test "terminating a table and eternal" do
    tab = create(:terminating_table, [])

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    Eternal.terminate(tab)

    :timer.sleep(50)

    refute(Process.alive?(owner))
    refute(Process.alive?(heir))

    assert_raise(ArgumentError, fn ->
      :ets.first(tab)
    end)
  end

  test "logging output when creating a table" do
    msg = capture_log(fn ->
      Eternal.new(:terminating_table)
      :timer.sleep(250)
    end)

    IO.puts(msg)

    assert(Regex.match?(~r/\[debug\] \[eternal\] Table \d+ gifted to #PID<\d\.\d{3}\.\d> via #PID<\d\.\d{3}\.\d>/, msg))
  end

  defp create(name, tab_opts \\ [], opts \\ []) do
    tab = Eternal.new(name, tab_opts, opts ++ [ quiet: true ])

    on_exit(fn ->
      Eternal.terminate(tab)
    end)

    tab
  end

end
