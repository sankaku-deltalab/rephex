defmodule RephexTest do
  use ExUnit.Case

  alias Phoenix.LiveView.AsyncResult

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture

  doctest Rephex

  test "add count" do
    socket = Fixture.new_socket_with_slices() |> CounterSlice.add_count(%{amount: 1})

    assert CounterSlice.count(socket.assigns.__rephex__) == 1
  end

  test "add count delayed" do
    socket =
      Fixture.new_socket_with_slices() |> CounterSlice.add_count_delayed(%{amount: 2, delay: 100})

    root = socket.assigns.__rephex__
    assert CounterSlice.count(root) == 0
    assert CounterSlice.loading_status(root) == :loading
  end
end
