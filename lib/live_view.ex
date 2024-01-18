defmodule Rephex.LiveView do
  defmacro __using__(_opt \\ []) do
    quote do
      use Rephex.AsyncAction.Handler
      use Rephex.LiveComponent.Handler
    end
  end
end
