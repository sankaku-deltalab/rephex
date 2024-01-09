defmodule RephexTest.Fixture.CounterState do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  alias RephexTest.Fixture.CounterState.{AddCountAsync, SomethingAsyncSingle}
  import Rephex.State.Assigns

  @type t :: %{
          count: integer(),
          loading_async: %AsyncResult{},
          something_async: %AsyncResult{}
        }

  @initial_state %{
    count: 0,
    loading_async: %AsyncResult{},
    something_async: %AsyncResult{}
  }

  use Rephex.State,
    async_modules: [AddCountAsync, SomethingAsyncSingle],
    initial_state: @initial_state

  # Action

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: amount} = _payload) when is_integer(amount) do
    update_state(socket, fn state -> %{state | count: state.count + amount} end)
  end

  @spec mlt_count(Socket.t(), %{mlt: integer()}) :: Socket.t()
  def mlt_count(%Socket{} = socket, %{mlt: mlt} = _payload) when is_integer(mlt) do
    update_state_in(socket, [:count], &(&1 * mlt))
  end
end

defmodule RephexTest.Fixture.CounterState.AddCountAsync do
  @type payload :: %{amount: 2, delay: 1000}
  @type message :: nil
  @type cancel_reason :: any()

  use Rephex.AsyncAction

  alias Phoenix.LiveView.{AsyncResult, Socket}
  import Rephex.State.Assigns
  alias RephexTest.Fixture.CounterState

  @impl true
  def before_async(%Socket{} = socket, %{amount: amount} = _payload) do
    case get_state_in(socket, [:loading_async]) do
      %AsyncResult{loading: nil} ->
        {:continue,
         socket
         |> CounterState.add_count(%{amount: amount})
         |> update_state_in([:loading_async], &AsyncResult.loading(&1))}

      _ ->
        {:abort, socket}
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
        |> CounterState.add_count(%{amount: amount})
        |> update_state_in([:loading_async], &AsyncResult.ok(&1, amount))

      {:exit, _} ->
        socket
    end
  end

  @impl true
  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  @impl true
  def before_cancel(%Socket{} = socket, _reason) do
    {:continue, socket}
  end
end

# defmodule RephexTest.Fixture.CounterState.SomethingAsyncSingle do
#   @type payload :: %{}
#   @type result :: String.t()
#   @type cancel_reason :: any()

#   @key :something_async

#   use Rephex.AsyncActionSingle, key: @key

#   alias Phoenix.LiveView.{AsyncResult, Socket}
#   import Rephex.State.Assigns

#   @impl true
#   def before_async(%Socket{} = socket, _payload), do: {:continue, socket}

#   @impl true
#   def start_async(
#         %{@key => %AsyncResult{} = async} = state,
#         %{} = _payload,
#         update_async
#       ) do
#     if async.loading != nil, do: raise({:shutdown, :already_loading})

#     for i <- 0..4 do
#       update_async.({i, 5})
#       :timer.sleep(200)
#     end

#     "ok ok ok"
#   end

#   @impl true
#   def resolve_exit(%Socket{} = socket, reason) do
#     Assigns.upd_in(socket, [@key], &AsyncResult.failed(&1, reason))
#   end

#   @impl true
#   def before_cancel(%Socket{} = socket, _reason), do: {:continue, socket}
# end
