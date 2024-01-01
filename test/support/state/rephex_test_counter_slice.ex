defmodule RephexTest.Fixture.State.CounterSlice do
  @behaviour Rephex.Slice

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.State.CounterSlice.AddCountAsync

  @type t :: %{count: integer(), loading_async: %AsyncResult{}, add_async_failed: boolean()}
  @initial_state %{
    count: 0,
    loading_async: %AsyncResult{},
    add_async_failed: false
  }

  defmodule Support do
    use Rephex.Slice.Support, slice: RephexTest.Fixture.State.CounterSlice
  end

  @impl true
  def slice_info() do
    %{initial_state: @initial_state, async_modules: [AddCountAsync]}
  end

  # Action

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: amount} = _payload) when is_integer(amount) do
    Support.update_slice(socket, fn state ->
      %{state | count: state.count + amount}
    end)
  end

  # Async action

  @spec add_count_delayed(
          socket :: Socket.t(),
          payload :: %{amount: integer(), delay: non_neg_integer()}
        ) ::
          Socket.t()
  def add_count_delayed(%Socket{} = socket, %{amount: _, delay: _} = payload) do
    Support.start_async(socket, AddCountAsync, payload)
  end

  @spec cancel_add_count_delayed(Socket.t(), any()) :: Socket.t()
  def cancel_add_count_delayed(%Socket{} = socket, _payload) do
    Support.cancel_async(socket, AddCountAsync)
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
  @behaviour Rephex.AsyncAction

  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.State.CounterSlice
  alias RephexTest.Fixture.State.CounterSlice.Support

  @impl true
  @spec before_async(Socket.t(), map()) :: {:continue, Socket.t()} | {:abort, Socket.t()}
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
end
