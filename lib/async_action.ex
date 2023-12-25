defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
  @callback receive_message(socket :: Socket.t(), content :: any()) :: Socket.t()
end
