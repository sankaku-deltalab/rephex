defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback start(Socket.t(), map()) :: Socket.t()
  @callback resolve(Socket.t(), {:ok, any()} | {:exit, any()}) :: Socket.t()
end
