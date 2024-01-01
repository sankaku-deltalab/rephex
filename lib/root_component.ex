defmodule Rephex.RootComponent do
  alias Phoenix.LiveView.Socket
  alias Rephex.RootComponent.Support

  defmacro __using__([state: state] = _opt) do
    quote do
      @__async_module_to_slice Rephex.State.Support.get_async_module_to_slice_map(
                                 unquote(state).slice_modules()
                               )
      @__async_modules @__async_module_to_slice |> Map.keys()

      @impl true
      def handle_info({Rephex.AsyncAction, async_module, content} = msg, %Socket{} = socket)
          when is_atom(async_module) do
        Support.handle_info(msg, socket, async_module_to_slice: @__async_module_to_slice)
      end

      @impl true
      def handle_async(name, async_fun_result, %Socket{} = socket)
          when name in @__async_modules do
        Support.handle_async(name, async_fun_result, socket)
      end
    end
  end
end

defmodule Rephex.RootComponent.Support do
  alias Phoenix.LiveView.Socket

  def handle_info(
        {Rephex.AsyncAction, async_module, content} = _msg,
        %Socket{} = socket,
        async_module_to_slice: %{} = async_module_to_slice
      )
      when is_atom(async_module) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must not receive message in async on propagated state.")

    if Map.has_key?(async_module_to_slice, async_module) do
      {:noreply, async_module.receive_message(socket, content)}
    else
      raise {:not_async_module, async_module}
    end
  end

  def handle_async(name, async_fun_result, %Socket{} = socket) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must not resolve async on propagated state.")

    {:noreply, name.resolve(socket, async_fun_result)}
  end
end
