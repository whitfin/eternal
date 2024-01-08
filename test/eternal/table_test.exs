defmodule Eternal.TableTest do
  use ExUnit.Case

  alias Eternal.Table

  import Table

  test "converting an atom name" do
    assert(Table.to_name(:test) == :test)
  end

  test "converting an integer name" do
    assert(Table.to_name(12345, true) == :"12345")
  end

  test "converting a missing integer name" do
    assert(Table.to_name(54321) == nil)
  end

  test "is_table/1 with a table identifier" do
    assert(detect(12345) == true)
  end

  test "is_table/1 with a table name" do
    assert(detect(:test) == true)
  end

  test "is_table/1 with an invalid id" do
    refute(detect("test") == true)
  end

  defp detect(tab) when is_table(tab),
    do: true

  defp detect(_tab),
    do: false
end
