defmodule PlutaTest do
  use ExUnit.Case
  doctest Pluta

  test "greets the world" do
    assert Pluta.hello() == :world
  end
end
