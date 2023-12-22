defmodule RephexTest do
  use ExUnit.Case

  alias Phoenix.LiveView.AsyncResult

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture

  doctest Rephex

  test "add count" do
    socket = Fixture.new_socket_with_slices() |> CounterSlice.add_count(%{amount: 1})

    slice_state = CounterSlice.Support.get_slice(socket)
    assert slice_state == %{count: 1, loading_async: %AsyncResult{}}
  end

  test "add count delayed" do
    socket =
      Fixture.new_socket_with_slices() |> CounterSlice.add_count_delayed(%{amount: 2, delay: 100})

    slice_state = CounterSlice.Support.get_slice(socket)

    assert slice_state == %{
             count: 0,
             loading_async: AsyncResult.loading()
           }
  end
end
