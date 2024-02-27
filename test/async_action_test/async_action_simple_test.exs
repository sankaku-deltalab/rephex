defmodule RephexTest.AsyncAction.Simple do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  alias RephexTest.Fixture.CounterState
  alias RephexTest.Fixture

  test "start_async turn AsyncResult to loading immediately" do
    Rephex.Api.MockLiveViewApi
    |> expect(:start_async, fn socket, _name, _fun -> socket end)

    socket =
      Fixture.new_socket_with_slices()
      |> CounterState.SomethingAsyncSimple.start(%{text: "a"})

    async_result = Rephex.State.Assigns.get_state_in(socket, [:something_async])

    assert async_result.loading == true
  end
end
