defmodule RephexTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  alias Phoenix.LiveView.AsyncResult
  alias RephexTest.Fixture.CounterState
  alias RephexTest.Fixture

  doctest Rephex

  test "add count" do
    socket = Fixture.new_socket_with_slices() |> CounterState.add_count(%{amount: 1})

    state = Rephex.State.Assigns.get_state(socket)
    assert state.count == 1
  end

  test "get element in socket" do
    socket = Fixture.new_socket_with_slices() |> CounterState.add_count(%{amount: 1})

    count_1 = Rephex.State.Assigns.get_state(socket).count
    count_2 = Rephex.State.Assigns.get_state_in(socket, [:count])

    assert count_1 == 1
    assert count_2 == 1
  end

  test "mlt count" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterState.add_count(%{amount: 1})
      |> CounterState.mlt_count(%{mlt: 2})

    state = Rephex.State.Assigns.get_state(socket)
    assert state.count == 2
  end

  test "continue add count delayed" do
    Rephex.Api.MockLiveViewApi
    |> expect(:start_async, fn socket, _name, _fun -> socket end)

    socket =
      Fixture.new_socket_with_slices()
      |> CounterState.AddCountAsync.start(%{amount: 2, delay: 1000})

    state = Rephex.State.Assigns.get_state(socket)

    assert state.count == 2
  end

  test "abort add count delayed" do
    socket =
      Fixture.new_socket_with_slices()
      |> Rephex.State.Assigns.update_state_in([:loading_async], &AsyncResult.loading(&1))
      |> CounterState.AddCountAsync.start(%{amount: 2, delay: 1000})

    state = Rephex.State.Assigns.get_state(socket)

    assert state.count == 0
  end
end
