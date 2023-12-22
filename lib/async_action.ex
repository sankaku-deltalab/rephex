defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback start(socket :: Socket.t(), payload :: map()) :: Socket.t()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
end
