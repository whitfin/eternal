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

  test "deprecation warnings when using new/3" do
    msg = capture_log(fn ->
      tab = Eternal.new(:deprecation_new, [], [ quiet: true ])
      Eternal.stop(tab)
      assert(is_number(tab))
    end)

    assert(Regex.match?(~r/\[warn\]  Deprecation Notice: Eternal\.new\/3 is deprecated! Please use Eternal\.start_link\/3 instead\./, msg))
  end

  test "deprecation warnings when using terminate/1" do
    msg = capture_log(fn ->
      :deprecation_terminate
      |> create([], [ quiet: true ])
      |> Eternal.terminate
    end)

    assert(Regex.match?(~r/\[warn\]  Deprecation Notice: Eternal\.terminate\/1 is deprecated! Please use Eternal\.stop\/1 instead\./, msg))
  end

  defp create(name, tab_opts \\ [], opts \\ []) do
    { :ok, _pid } = Eternal.start_link(name, tab_opts, opts ++ [ quiet: true ])
    name
  end

end
