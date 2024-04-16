defmodule Rephex do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.fetch!(1)

  @root Application.compile_env(:rephex, :root, :rpx)

  @doc """
  Get root key of Rephex state. Default key is `:rpx`.
  Rephex state will be contained at `socket.assigns[Rephex.root()]`.

  You can change key by config.

  Example:

      config :rephex, root: :my_rpx

  """
  @spec root() :: atom()
  def root(), do: @root
end
