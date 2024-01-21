defmodule RephexTest.AsyncAction.Simple do
  use ExUnit.Case

  alias RephexTest.Fixture.CounterState
  alias RephexTest.Fixture

  doctest Rephex

  test "start_async turn AsyncResult to loading immediately" do
    socket =
      Fixture.new_socket_with_slices()
      |> CounterState.SomethingAsyncSimple.start(%{text: "a"})

    async_result = Rephex.State.Assigns.get_state_in(socket, [:something_async])

    assert async_result.loading == true
  end
end
