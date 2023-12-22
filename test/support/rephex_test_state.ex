defmodule RephexTest.Fixture.State.CounterSlice do
  @behaviour Rephex.Slice

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  @type t :: %{count: integer(), loading_async: %AsyncResult{}}
  @initial_state %{
    count: 0,
    loading_async: %AsyncResult{}
  }

  defmodule Support do
    use Rephex.Slice.Support, name: :counter
  end

  alias RephexTest.Fixture.State.CounterSlice.AddCountAsync

  @impl true
  def slice_info() do
    %{name: :counter, initial_state: @initial_state, async_modules: [AddCountAsync]}
  end

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: amount} = _payload) when is_integer(amount) do
    Support.update_slice(socket, fn state ->
      %{state | count: state.count + amount}
    end)
  end

  @spec add_count_delayed(
          socket :: Socket.t(),
          payload :: %{amount: integer(), delay: non_neg_integer()}
        ) ::
          Socket.t()
  def add_count_delayed(%Socket{} = socket, %{amount: amount, delay: delay} = payload)
      when is_integer(amount) and is_integer(delay) do
    socket
    |> Support.start_async(AddCountAsync, payload)
    |> Support.set_async_as_loading!(:loading_async)
  end
end

defmodule RephexTest.Fixture.State.CounterSlice.AddCountAsync do
  @behaviour Rephex.AsyncAction

  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture.State.CounterSlice.Support

  @impl true
  def start_async(_state, %{amount: amount, delay: delay} = _payload)
      when is_integer(amount) and is_integer(delay) do
    :timer.sleep(delay)
    amount
  end

  @impl true
  def resolve(%Socket{} = socket, result) do
    case result do
      {:ok, amount} ->
        socket
        |> CounterSlice.add_count(amount)
        |> Support.set_async_as_ok!(:loading_async, amount)

      {:exit, _} ->
        socket
    end
  end
end

defmodule RephexTest.Fixture.State do
  alias RephexTest.Fixture.State.CounterSlice
  use Rephex.State, slices: [CounterSlice]
end
