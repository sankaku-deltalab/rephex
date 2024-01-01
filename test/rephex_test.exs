defmodule RephexTest do
  use ExUnit.Case

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture

  doctest Rephex

  test "add count" do
    socket = Fixture.new_socket_with_slices() |> CounterSlice.add_count(%{amount: 1})

    slice = Rephex.State.get_slice(socket, CounterSlice)
    assert slice.count == 1
  end

  test "continue add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.AddCountAsync.start(%{amount: 2, delay: 1000})

    slice = Rephex.State.get_slice(socket, CounterSlice)

    assert slice.count == 0
    assert CounterSlice.loading_status(slice) == :loading
    assert slice.add_async_failed == false
  end

  test "abort add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.Support.reset_async!(:loading_async, loading: true)
      |> CounterSlice.AddCountAsync.start(%{amount: 2, delay: 1000})

    slice = Rephex.State.get_slice(socket, CounterSlice)

    assert slice.count == 0
    assert CounterSlice.loading_status(slice) == :loading
    assert slice.add_async_failed == true
  end
end
