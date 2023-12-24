defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map()) :: any()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
end
