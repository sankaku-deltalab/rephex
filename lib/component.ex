defmodule Rephex.Component do
  use Phoenix.Component

  @doc """
  Example:
  ```html
  <.slice_component :let={counter_slice} root={@__rephex__} slice={:counter}>
    <span>Count: {counter_slice.count()}</span>
  </.slice_component>
  ```
  """
  slot(:inner_block, required: true)
  attr(:root, :map, required: true)
  attr(:slice, :atom, required: true)

  def slice_component(assigns) do
    ~H"""
    <%= render_slot(@inner_block, Rephex.State.Support.get_slice_from_root(@root, @slice)) %>
    """
  end
end
