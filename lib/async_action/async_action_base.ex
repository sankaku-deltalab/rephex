defmodule Rephex.AsyncAction.Base do
  alias Phoenix.LiveView.Socket

  @type result :: any()
  @type cancel_reason :: any()
  @type message :: any()

  @callback resolve(
              socket :: Socket.t(),
              result :: {:ok, result()} | {:exit, cancel_reason()}
            ) :: Socket.t()

  @callback receive_message(socket :: Socket.t(), message :: message()) :: Socket.t()
end

defmodule Rephex.AsyncAction.Handler do
  alias Phoenix.LiveView.Socket

  defmacro __using__(opt) do
    async_modules = Keyword.fetch!(opt, :async_modules)

    quote do
      @impl true
      def handle_info({Rephex.AsyncAction, async_module, _message} = msg, %Socket{} = socket)
          when is_atom(async_module) and async_module in unquote(async_modules) do
        Rephex.AsyncAction.Handler.handle_info_by_async_message(msg, socket)
      end

      @impl true
      def handle_info({Rephex.AsyncAction, async_module, _message} = msg, %Socket{} = socket) do
        raise(
          "Unknown async module: #{inspect(async_module)}. async_modules: #{inspect(unquote(async_modules))}"
        )
      end

      @impl true
      def handle_async(name, async_fun_result, %Socket{} = socket)
          when name in unquote(async_modules) do
        Rephex.AsyncAction.Handler.handle_async_action(name, async_fun_result, socket)
      end
    end
  end

  def handle_info_by_async_message(
        {Rephex.AsyncAction, async_module, message} = _msg,
        %Socket{} = socket
      )
      when is_atom(async_module) do
    # NOTE: Caller must check `async_module` in async modules.
    if socket.parent_pid != nil,
      do: raise("Must not receive message in async on propagated state.")

    {:noreply, async_module.receive_message(socket, message)}
  end

  def handle_async_action(async_module, async_fun_result, %Socket{} = socket) do
    # NOTE: Caller must check `async_module` in async modules.
    {:noreply, async_module.resolve(socket, async_fun_result)}
  end
end
