defmodule Rephex.LiveComponent do
  @moduledoc """
  Implement utility functions and handling functions for Rephex by `use Rephex.LiveComponent`.

  ## Example

      defmodule ExampleWeb.AccountLive.ComponentA do
        use ExampleWeb, :live_component
        use Rephex.LiveComponent

        @initial_local_state %{
          count_double: 0
        }

        @impl true
        def mount(%Socket{} = socket) do
          {:ok, socket |> assign(@initial_local_state)}
        end

        @impl true
        def update(assigns, socket) do
          {:ok,
          socket
          |> propagate_rephex(assigns)
          |> assign(:count_double, assigns.rpx.count * 2)}
        end

        def handle_event("event_in_component", params, socket) do
          # Mutate Rephex state in root LiveView
          {:noreply,
          socket
          |> call_in_root(fn state -> mutation(state) end)}
        end
      end
  """
  import Phoenix.Component

  @root Rephex.root()

  alias Phoenix.LiveView.Socket
  alias Rephex.Api.KernelApi

  defmacro __using__(_opt \\ []) do
    quote do
      # Do not use Rephex.LiveComponent.Handler because it is for LiveView.
      import Rephex.LiveComponent
    end
  end

  @doc """
  Assign rephex state to socket assigns in LiveComponent.
  WARN: Do NOT use this function in LiveView (root).

  Example:

      def update(%{rpx: _} = assigns, socket) do
        {:ok,
        socket
        |> propagate_rephex(assigns)
        |> assign(other_state)}
      end
  """
  @spec propagate_rephex(Socket.t(), map()) :: Socket.t()
  def propagate_rephex(%Socket{} = socket, %{@root => %{} = state} = _assigns) do
    socket |> assign(@root, state)
  end

  @doc """
  Call function in root LiveView.

  Example:

      def handle_event("event_in_component", params, socket) do
        {:noreply,
        socket
        |> call_in_root(fn state -> mutation(state) end)}
      end
  """
  @spec call_in_root(v, (Socket.t() -> Socket.t())) :: v when v: any()
  def call_in_root(any, fun) when is_function(fun, 1) do
    KernelApi.send(self(), {{Rephex.LiveComponent, :call_in_root}, fun})
    any
  end
end

defmodule Rephex.LiveComponent.Handler do
  alias Phoenix.LiveView.Socket

  defmacro __using__(_opt \\ []) do
    quote do
      @impl true
      def handle_info({{Rephex.LiveComponent, :call_in_root}, _fun} = msg, %Socket{} = socket) do
        Rephex.LiveComponent.Handler.handle_info_by_call_in_root(msg, socket)
      end
    end
  end

  def handle_info_by_call_in_root(
        {{Rephex.LiveComponent, :call_in_root}, fun} = _msg,
        %Socket{} = socket
      ) do
    if socket.parent_pid != nil,
      do: raise("Must not receive message in async on propagated state.")

    if not is_function(fun, 1), do: raise({:not_function, fun})

    {:noreply, fun.(socket)}
  end
end
