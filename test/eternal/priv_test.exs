defmodule Eternal.PrivTest do
  use ExUnit.Case

  alias Eternal.Priv

  import Priv

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

  defp detect(a, b, c) when is_opts(a, b, c),
    do: true
  defp detect(_a, _b, _c),
    do: false
end
