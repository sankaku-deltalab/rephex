defmodule Rephex.AsyncAction.Handler do
  alias Phoenix.LiveView.Socket

  defmacro __using__(_opt \\ []) do
    quote do
      @impl true
      def handle_info(
            {Rephex.AsyncAction.Backend, :update_progress, {action_module, result_path},
             progress},
            %Socket{} = socket
          )
          when is_atom(action_module) and is_list(result_path) do
        {:noreply,
         Rephex.AsyncAction.Backend.update_progress(
           socket,
           {action_module, result_path},
           progress
         )}
      end

      @impl true
      def handle_async(
            {Rephex.AsyncAction.Backend, :start_async, {action_module, result_path}},
            result,
            %Socket{} = socket
          )
          when is_atom(action_module) and is_list(result_path) do
        {:noreply,
         Rephex.AsyncAction.Backend.resolve(socket, {action_module, result_path}, result)}
      end
    end
  end
end
