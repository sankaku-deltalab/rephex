# defmodule RephexTest.Api.AsyncAction do
#   @callback before_async(socket :: Socket.t(), payload :: map()) ::
#               {:continue, Socket.t()} | {:abort, Socket.t()}
#   @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
#   @callback before_cancel(socket :: Socket.t(), reason :: any()) ::
#               {:continue, Socket.t()} | {:abort, Socket.t()}

#   def before_async(socket, payload) do
#     impl().before_async(socket, payload)
#   end

#   def before_cancel(socket, reason) do
#     impl().before_cancel(socket, reason)
#   end

#   def receive_message(socket, message) do
#     impl().receive_message(socket, message)
#   end

#   def resolve(socket, result) do
#     impl().resolve(socket, result)
#   end

#   def start_async(state, payload, send_msg) do
#     impl().start_async(state, payload, send_msg)
#   end

#   defp impl, do: Application.get_env(:rephex_test, :async_action_api)
# end

# defmodule RephexTest.Fixture.AsyncAction do
#   use Rephex.AsyncAction, payload_type: map(), cancel_reason_type: any()

#   def before_async(socket, payload) do
#     RephexTest.Api.AsyncAction.before_async(socket, payload)
#   end

#   def before_cancel(socket, reason) do
#     RephexTest.Api.AsyncAction.before_cancel(socket, reason)
#   end

#   def receive_message(socket, message) do
#     RephexTest.Api.AsyncAction.receive_message(socket, message)
#   end

#   def resolve(socket, result) do
#     RephexTest.Api.AsyncAction.resolve(socket, result)
#   end

#   def start_async(state, payload, send_msg) do
#     RephexTest.Api.AsyncAction.start_async(state, payload, send_msg)
#   end
# end
