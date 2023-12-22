defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback start_async(state :: map(), payload :: map()) :: any()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
end
