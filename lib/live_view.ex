defmodule Rephex.LiveView do
  @moduledoc """
  Implement handling functions for Rephex by `use Rephex.LiveView`.

  ## Example

      defmodule ExampleWeb.AccountLive.Index do
        use ExampleWeb, :live_view
        use Rephex.LiveView

        @impl true
        def mount(_params, _session, socket) do
          {:ok, socket |> ExampleWeb.State.init()}
        end

        @impl true
        def render(assigns) do
          ~H'''
          <div>Hello!</div>
          '''
        end
      end
  """
  defmacro __using__(_opt \\ []) do
    quote do
      use Rephex.AsyncAction.Handler
      use Rephex.LiveComponent.Handler
    end
  end
end
