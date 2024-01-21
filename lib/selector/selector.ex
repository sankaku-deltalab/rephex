defprotocol Rephex.Selectable do
  alias Phoenix.LiveView.Socket

  @type selectable :: any()

  @spec update_in_socket(selectable(), Socket.t(), [any()]) :: Socket.t()
  def update_in_socket(selectable, socket, selectable_keys)
end

defmodule Rephex.Selector do
  alias Phoenix.LiveView.Socket

  @type option :: {:priority, [any()]} | {:exclude, [any()]}
  @spec update_in_socket(Socket.t()) :: Socket.t()
  @spec update_in_socket(Socket.t(), [option]) :: Socket.t()
  def update_in_socket(%Socket{} = socket, opts \\ []) do
    priority = Keyword.get(opts, :priority, []) |> Enum.map(&[&1])
    exclude = Keyword.get(opts, :exclude, []) |> Enum.map(&[&1])

    update_keys_list = calc_update_order(socket.assigns, priority, exclude)

    socket
    |> update_selectable_assigns(update_keys_list)
  end

  defp calc_update_order(%{} = assigns, priority, exclude) do
    priority_set = MapSet.new(priority)
    exclude_set = MapSet.new(exclude)
    priority_keys_list = Enum.filter(priority, &(&1 not in exclude_set))

    other_keys_list =
      assigns
      |> collect_selectable()
      |> Stream.filter(fn {keys, _v} -> keys not in priority_set end)
      |> Stream.filter(fn {keys, _v} -> keys not in exclude_set end)
      |> Stream.map(fn {keys, _} -> keys end)
      |> Enum.to_list()

    priority_keys_list ++ other_keys_list
  end

  defp update_selectable_assigns(socket, keys_list) do
    Enum.reduce(keys_list, socket, fn keys, socket ->
      selectable = get_in(socket.assigns, keys)
      Rephex.Selectable.update_in_socket(selectable, socket, keys)
    end)
  end

  defp collect_selectable(assigns) do
    # collect only not-nested selectable
    # %{a: %AnySelectable{}} -> [{[:a], %AnySelectable{}}]
    assigns
    |> Stream.filter(fn {_k, v} -> is_selectable(v) end)
    |> Stream.map(fn {k, v} -> {[k], v} end)
  end

  defp is_selectable(maybe_selectable) do
    Rephex.Selectable.impl_for(maybe_selectable) != nil
  end
end
