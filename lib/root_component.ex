defmodule Rephex.RootComponent do
  alias Phoenix.LiveView.Socket

  defmacro __using__([state: state] = _opt) do
    quote do
      @__async_module_to_slice Rephex.State.Support.get_async_module_to_slice_map(
                                 unquote(state).slice_modules()
                               )
      @__async_modules @__async_module_to_slice |> Map.keys()

      @impl true
      def handle_info({Rephex.AsyncAction, async_module, content} = msg, %Socket{} = socket)
          when is_atom(async_module) do
        if Rephex.State.Support.propagated?(socket),
          do: raise("Must not receive message in async on propagated state.")

        if Map.has_key?(@__async_module_to_slice, async_module) do
          {:noreply, async_module.receive_message(socket, content)}
        else
          raise {:not_async_module, async_module}
        end
      end

      @impl true
      def handle_async(name, async_fun_result, %Socket{} = socket)
          when name in @__async_modules do
        if Rephex.State.Support.propagated?(socket),
          do: raise("Must not resolve async on propagated state.")

        {:noreply, name.resolve(socket, async_fun_result)}
      end
    end
  end
end
