defmodule Rephex.Api.KernelApi do
  @moduledoc """
  The behaviour for the Kernel sub-effect.
  """
  @callback send(dest :: Process.dest(), message) :: message when message: any()

  @behaviour Rephex.Api.KernelApi

  def send(dest, message), do: impl().send(dest, message)
  defp impl, do: Application.get_env(:rephex, :kernel_api, Rephex.Api.KernelApi.Impl)
end

defmodule Rephex.Api.KernelApi.Impl do
  @moduledoc """
  The implementation of the Kernel sub-effect.
  """
  @behaviour Rephex.Api.KernelApi

  def send(dest, message) do
    Kernel.send(dest, message)
  end
end
