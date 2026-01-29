defmodule Eternal.SupervisorTest do
  use ExUnit.Case

  alias Eternal.Supervisor

  describe "start_link/3" do
    test "ensure clashes are detected" do
      assert {:ok, pid, :supervisor_test_cache} = Supervisor.start_link(:supervisor_test_cache)

      assert {:error, {:already_started, ^pid}} = Supervisor.start_link(:supervisor_test_cache)
    end
  end
end
