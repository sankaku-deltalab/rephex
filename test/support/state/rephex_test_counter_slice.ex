defmodule RephexTest.Fixture.State.CounterSlice do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.State.CounterSlice.AddCountAsync

  @type t :: %{count: integer(), loading_async: %AsyncResult{}, add_async_failed: boolean()}
  @initial_state %{
    count: 0,
    loading_async: %AsyncResult{},
    add_async_failed: false
  }

  use Rephex.Slice, initial_state: @initial_state, async_modules: [AddCountAsync]

  # Action

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: amount} = _payload) when is_integer(amount) do
    Support.update_slice(socket, fn state ->
      %{state | count: state.count + amount}
    end)
  end

  # Selector

  @spec loading_status(t()) :: :failed | :loading | :not_loaded | :ok
  def loading_status(%{loading_async: async} = _slice) do
    case async do
      %AsyncResult{loading: true} -> :loading
      %AsyncResult{failed: f} when f != nil -> :failed
      %AsyncResult{ok?: true} -> :ok
      _ -> :not_loaded
    end
  end
end

defmodule RephexTest.Fixture.State.CounterSlice.AddCountAsync do
  @type payload :: %{amount: 2, delay: 1000}
  @type message :: nil

  use Rephex.AsyncAction, slice: RephexTest.Fixture.State.CounterSlice

  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture.State.CounterSlice.Support

  @impl true
  def before_async(%Socket{} = socket, _payload) do
    loading_status =
      socket
      |> Support.get_slice()
      |> CounterSlice.loading_status()

    case loading_status do
      :loading ->
        socket =
          Support.update_slice(socket, fn state ->
            %{state | add_async_failed: true}
          end)

        {:abort, socket}

      _ ->
        {
          :continue,
          socket
          |> Support.update_async!(:loading_async, loading: true)
        }
    end
  end

  @impl true
  def start_async(_state, %{amount: amount, delay: delay} = _payload, _send_msg)
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
        |> Support.update_async!(:loading_async, ok: amount)

      {:exit, _} ->
        socket
    end
  end

  @impl true
  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  @impl true
  def canceled(%Socket{} = socket, _reason) do
    socket
  end
end
