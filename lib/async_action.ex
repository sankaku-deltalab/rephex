defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
  @callback receive_message(socket :: Socket.t(), message :: any()) :: Socket.t()
  @callback before_cancel(socket :: Socket.t(), reason :: any()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}

  defmacro __using__(_opt \\ []) do
    quote do
      @behaviour Rephex.AsyncAction

      # NOTE: `@type payload`, `@type cancel_reason` must be defined.

      @spec start(Socket.t(), payload()) :: any()
      def start(socket, payload) do
        Rephex.AsyncAction.start_async_action(socket, payload, async_module: __MODULE__)
      end

      @spec cancel(Socket.t(), cancel_reason()) :: Socket.t()
      def cancel(%Socket{} = socket, reason \\ {:shutdown, :cancel}) do
        Rephex.AsyncAction.cancel_async_action(socket,
          async_module: __MODULE__,
          reason: reason
        )
      end
    end
  end

  def start_async_action(%Socket{parent_pid: parent_pid}, _payload, _opt) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def start_async_action(%Socket{} = socket, payload, async_module: async_module)
      when is_atom(async_module) do
    case async_module.before_async(socket, payload) do
      {:continue, %Socket{} = socket} ->
        state = Rephex.State.Assigns.get_state(socket)
        lv_pid = self()
        send_msg = fn msg -> send(lv_pid, {Rephex.AsyncAction, async_module, msg}) end
        fun_raw = &async_module.start_async/3
        fun_for_async = fn -> fun_raw.(state, payload, send_msg) end

        Phoenix.LiveView.start_async(socket, async_module, fun_for_async)

      {:abort, %Socket{} = socket} ->
        socket
    end
  end

  def cancel_async_action(%Socket{parent_pid: parent_pid}, _opt) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def cancel_async_action(
        %Socket{} = socket,
        async_module: async_module,
        reason: reason
      )
      when is_atom(async_module) do
    case async_module.before_cancel(socket, reason) do
      {:continue, %Socket{} = socket} ->
        Phoenix.LiveView.cancel_async(socket, async_module, reason)

      {:abort, %Socket{} = socket} ->
        socket
    end
  end
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
