defmodule Rephex.Component do
  use Phoenix.Component

  alias Phoenix.LiveView.Socket

  @doc """
  Example:
  ```html
  <.slice_component :let={counter_slice} root={@__rephex__} slice={CounterSlice}>
    <span>Count: {counter_slice.count()}</span>
  </.slice_component>
  ```
  """
  slot(:inner_block, required: true)
  attr(:root, :map, required: true)
  attr(:slice, :atom, required: true)

  def slice_component(assigns) do
    ~H"""
    <%= render_slot(@inner_block, Rephex.State.get_slice!(@root, @slice)) %>
    """
  end

  @doc """
  Assign rephex state to socket assigns in LiveComponent.
  WARN: Do NOT use this function in LiveView (root).

  Example:

  ```ex
  def update(%{__rephex__: _} = assigns, socket) do
    {:ok,
     socket
     |> propagate_rephex(assigns)
     |> assign(other_state)}
  end
  ```
  """
  @spec propagate_rephex(Socket.t(), %{__rephex__: %Rephex.State{}}) :: Socket.t()
  def propagate_rephex(%Socket{} = socket, %{__rephex__: %Rephex.State{} = root} = _assigns) do
    socket
    |> assign(Rephex.root(), Rephex.State.propagate(root))
  end

  @doc """
  Call function in root LiveView.

  Example:

  ```ex
  def handle_event("event_in_component", params, socket) do
    {:noreply,
     socket
     |> call_in_root(&mutate_function(&1, params))}
  end
  ```
  """
  @spec call_in_root(v, (Socket.t() -> Socket.t())) :: v when v: any()
  def call_in_root(any, fun) when is_function(fun, 1) do
    send(self(), {{Rephex.LiveComponent, :call_in_root}, fun})
    any
  end
end
