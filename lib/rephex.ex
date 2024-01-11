defmodule Rephex do
  @root Application.compile_env(:rephex, :root, :rpx)

  @spec root() :: atom()
  def root(), do: @root
end
