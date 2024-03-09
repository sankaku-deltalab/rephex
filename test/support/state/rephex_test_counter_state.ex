defmodule RephexTest.Fixture.CounterState do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

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

# defmodule RephexTest.Fixture.CounterState.AddCountAsync do
#   @type payload :: %{amount: 2, delay: 1000}
#   @type message :: nil
#   @type cancel_reason :: any()

#   use Rephex.AsyncAction, payload_type: payload, cancel_reason_type: cancel_reason

#   alias Phoenix.LiveView.{AsyncResult, Socket}
#   import Rephex.State.Assigns
#   alias RephexTest.Fixture.CounterState

#   @impl true
#   def before_async(%Socket{} = socket, %{amount: amount} = _payload) do
#     case get_state_in(socket, [:loading_async]) do
#       %AsyncResult{loading: nil} ->
#         {:continue,
#          socket
#          |> CounterState.add_count(%{amount: amount})
#          |> update_state_in([:loading_async], &AsyncResult.loading(&1))}

#       _ ->
#         {:abort, socket}
#     end
#   end

#   @impl true
#   def start_async(_state, %{amount: amount, delay: delay} = _payload, _send_msg)
#       when is_integer(amount) and is_integer(delay) do
#     :timer.sleep(delay)
#     amount
#   end

#   @impl true
#   def resolve(%Socket{} = socket, result) do
#     case result do
#       {:ok, amount} ->
#         socket
#         |> CounterState.add_count(%{amount: amount})
#         |> update_state_in([:loading_async], &AsyncResult.ok(&1, amount))

#       {:exit, _} ->
#         socket
#     end
#   end

#   @impl true
#   def receive_message(%Socket{} = socket, _content) do
#     socket
#   end

#   @impl true
#   def before_cancel(%Socket{} = socket, _reason) do
#     {:continue, socket}
#   end
# end

# defmodule RephexTest.Fixture.CounterState.SomethingAsyncSimple do
#   use Rephex.AsyncAction.Simple,
#     async_keys: [:something_async],
#     payload_type: %{},
#     cancel_reason_type: any()

#   @impl true
#   def start_async(_state, %{} = _payload, progress) do
#     for i <- 0..4 do
#       progress.({i, 5})
#       :timer.sleep(200)
#     end

#     "ok ok ok"
#   end
# end
