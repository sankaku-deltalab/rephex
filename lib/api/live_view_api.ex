defmodule Rephex.Api.LiveViewApi do
  @moduledoc """
  The behaviour for the LiveView sub-effect.
  """
  alias Phoenix.LiveView.Socket

  @callback start_async(
              socket :: Socket.t(),
              name :: term(),
              func :: (-> term())
            ) :: Socket.t()

  @callback cancel_async(
              socket :: Socket.t(),
              name :: term(),
              reason :: term()
            ) :: Socket.t()

  @behaviour Rephex.Api.LiveViewApi
  alias Phoenix.LiveView

  def start_async(socket, name, fun), do: impl().start_async(socket, name, fun)

  def cancel_async(socket, name, reason \\ {:shutdown, :cancel}),
    do: impl().cancel_async(socket, name, reason)

  defp impl, do: Application.get_env(:rephex, :live_view_api, Rephex.Api.LiveViewApi.Impl)
end

defmodule Rephex.Api.LiveViewApi.Impl do
  @moduledoc """
  The implementation of the LiveView sub-effect.
  """
  @behaviour Rephex.Api.LiveViewApi
  alias Phoenix.LiveView

  def start_async(socket, name, func) do
    LiveView.start_async(socket, name, func)
  end

  def cancel_async(socket, name, reason \\ {:shutdown, :cancel}) do
    LiveView.cancel_async(socket, name, reason)
  end
end
