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

  test "continue add count delayed" do
    socket =
      Fixture.new_socket_with_slices() |> CounterSlice.add_count_delayed(%{amount: 2, delay: 100})

    root = socket.assigns.__rephex__
    slice = CounterSlice.Support.get_slice(socket)

    assert CounterSlice.count(root) == 0
    assert CounterSlice.loading_status(root) == :loading
    assert slice.add_async_failed == false
  end

  test "abort add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.Support.set_async_as_loading!(:loading_async)
      |> CounterSlice.add_count_delayed(%{amount: 2, delay: 100})

    root = socket.assigns.__rephex__
    slice = CounterSlice.Support.get_slice(socket)

    assert CounterSlice.count(root) == 0
    assert CounterSlice.loading_status(root) == :loading
    assert slice.add_async_failed == true
  end
end
