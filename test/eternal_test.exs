defmodule EternalTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  test "starting a table successfully" do
    assert(match?({ :ok, _pid }, Eternal.start_link(:table_no_options, [], [ quiet: true ])))
  end

  test "starting a table with options" do
    assert(match?({ :ok, _pid }, Eternal.start_link(:table_with_options, [ :compressed ], [ quiet: true ])))
    assert(:ets.info(:table_with_options, :compressed) == true)
  end

  test "starting a table with no link" do
    spawn(fn ->
      Eternal.start(:unlinked, [], [ quiet: true ])
    end)

    :timer.sleep(25)

    assert(:unlinked in :ets.all())
  end

  test "recovering from a stopd owner" do
    tab = create(:recover_stopd_owner)

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    GenServer.stop(owner)

    :timer.sleep(5)

    assert(is_pid(owner))
    assert(owner != Eternal.owner(tab))
    assert(is_pid(heir))
    assert(heir != Eternal.heir(tab))
  end

  test "recovering from a stopped heir" do
    tab = create(:recover_stopped_heir)

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    GenServer.stop(heir)

    :timer.sleep(5)

    assert(owner == Eternal.owner(tab))
    assert(is_pid(heir))
    assert(heir != Eternal.heir(tab))
  end

  test "terminating a table and eternal" do
    tab = create(:terminating_table, [])

    owner = Eternal.owner(tab)
    heir = Eternal.heir(tab)

    Eternal.stop(tab)

    :timer.sleep(5)

    refute(Process.alive?(owner))
    refute(Process.alive?(heir))

    assert_raise(ArgumentError, fn ->
      :ets.first(tab)
    end)
  end

  test "logging output when creating a table" do
    msg = capture_log(fn ->
      Eternal.start_link(:logging_output)
      :timer.sleep(25)
      Eternal.stop(:logging_output)
    end)

    assert(Regex.match?(~r/\[debug\] \[eternal\] Table 'logging_output' gifted to #PID<\d\.\d+\.\d> via #PID<\d\.\d+\.\d>/, msg))
  end

  test "starting a table twice finds the previous owner" do
    { :ok, pid } = Eternal.start_link(:existing_table, [], [ quiet: true ])
    result2 = Eternal.start_link(:existing_table, [], [ quiet: true ])
    assert(result2 == { :error, { :already_started, pid } })
  end

  defp create(name, tab_opts \\ [], opts \\ []) do
    { :ok, _pid } = Eternal.start_link(name, tab_opts, opts ++ [ quiet: true ])
    name
  end
end
