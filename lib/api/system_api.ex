defmodule Rephex.Api.SystemApi do
  @moduledoc """
  The behaviour for the System sub-effect.
  """
  @callback monotonic_time(:millisecond) :: integer()

  @behaviour Rephex.Api.SystemApi

  def monotonic_time(:millisecond), do: impl().monotonic_time(:millisecond)

  defp impl, do: Application.get_env(:rephex, :system_api, Rephex.Api.SystemApi.Impl)
end

defmodule Rephex.Api.SystemApi.Impl do
  @moduledoc """
  The implementation of the System sub-effect.
  """
  @behaviour Rephex.Api.SystemApi

  def monotonic_time(:millisecond) do
    System.monotonic_time(:millisecond)
  end
end
