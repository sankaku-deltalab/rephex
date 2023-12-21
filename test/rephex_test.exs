defmodule RephexTest do
  use ExUnit.Case
  doctest Rephex

  test "greets the world" do
    assert Rephex.hello() == :world
  end
end
