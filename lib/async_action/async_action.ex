defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
  @callback before_cancel(socket :: Socket.t(), reason :: any()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}

  defmacro __using__(_opt \\ []) do
    quote do
      @behaviour Rephex.AsyncAction.Base
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
