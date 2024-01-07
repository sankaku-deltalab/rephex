defmodule RephexTest do
  use ExUnit.Case

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture

  doctest Rephex

  test "add count" do
    socket = Fixture.new_socket_with_slices() |> CounterSlice.add_count(%{amount: 1})

    slice = Rephex.State.Support.get_slice!(socket, CounterSlice)
    assert slice.count == 1
  end

  test "get element in socket" do
    socket = Fixture.new_socket_with_slices() |> CounterSlice.add_count(%{amount: 1})

    count_1 = CounterSlice.Support.get_slice(socket).count
    count_2 = CounterSlice.Support.get_slice_in(socket, [:count])

    assert count_1 == 1
    assert count_2 == 1
  end

  test "mlt count" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.add_count(%{amount: 1})
      |> CounterSlice.mlt_count(%{mlt: 2})

    slice = Rephex.State.Support.get_slice!(socket, CounterSlice)
    assert slice.count == 2
  end

  test "continue add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.AddCountAsync.start(%{amount: 2, delay: 1000})

    slice = Rephex.State.Support.get_slice!(socket, CounterSlice)

    assert slice.count == 0
    assert CounterSlice.loading_status(slice) == :loading
    assert slice.add_async_failed == false
  end

  test "abort add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterSlice.Support.reset_async!(:loading_async, loading: true)
      |> CounterSlice.AddCountAsync.start(%{amount: 2, delay: 1000})

    slice = Rephex.State.Support.get_slice!(socket, CounterSlice)

    assert slice.count == 0
    assert CounterSlice.loading_status(slice) == :loading
    assert slice.add_async_failed == true
  end
end
