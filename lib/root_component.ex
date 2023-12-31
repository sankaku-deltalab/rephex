defmodule Rephex.RootComponent do
  defmacro __using__([state: state_module] = _opt) do
    quote do
      @__async_modules__ unquote(state_module).async_modules()
      use Rephex.AsyncAction.Handler, async_modules: @__async_modules__
      use Rephex.Component.Handler
    end
  end
end
