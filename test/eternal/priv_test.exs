defmodule Eternal.PrivTest do
  use ExUnit.Case

  alias Eternal.Priv

  import Priv

  test "exec_with/3 and a matching condition" do
    val = exec_with { a, b, c }, { 1, 2, 3 } do
      a + b + c
    end
    assert(val == 6)
  end

  test "exec_with/3 and a non-matching condition" do
    val = exec_with { a, b, c }, { 1 } do
      a + b + c
    end
    assert(val == { 1 })
  end

  test "is_opts/3 with valid arguments" do
    assert(detect(:test, [], []) == true)
  end

  test "is_opts/3 with invalid name" do
    refute(detect(12345, [], []) == true)
  end

  test "is_opts/3 with invaid ets_opts" do
    refute(detect(:test, 1, []) == true)
  end

  test "is_opts/3 with invalid opts" do
    refute(detect(:test, [], 1) == true)
  end

  defp detect(a, b, c) when is_opts(a, b, c), do: true
  defp detect(_a, _b, _c), do: false

end
