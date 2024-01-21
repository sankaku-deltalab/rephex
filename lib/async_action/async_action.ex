defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket
  alias Rephex.AsyncAction.Handler

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
  @callback before_cancel(socket :: Socket.t(), reason :: any()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}

  @optional_callbacks before_async: 2, before_cancel: 2

  defmacro __using__(opt \\ []) do
    default_payload_type =
      quote do
        map()
      end

    default_cancel_reason_type =
      quote do
        any()
      end

    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @behaviour Rephex.AsyncAction

      @spec start(Socket.t(), unquote(payload_type)) :: Socket.t()
      def start(socket, payload) do
        Rephex.AsyncAction.start_async_action(socket, payload, async_module: __MODULE__)
      end

      @spec cancel(Socket.t()) :: Socket.t()
      @spec cancel(Socket.t(), unquote(cancel_reason_type)) :: Socket.t()
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
    mfa = {async_module, :before_async, 2}

    case Rephex.Util.call_optional(mfa, [socket, payload], {:continue, socket}) do
      {:continue, %Socket{} = socket} ->
        state = Rephex.State.Assigns.get_state(socket)
        lv_pid = self()
        send_msg = &Handler.send_message_from_action(lv_pid, async_module, &1)
        fun_raw = &async_module.start_async/3
        fun_for_async = fn -> fun_raw.(state, payload, send_msg) end

        Handler.start_async_by_action(socket, async_module, fun_for_async)

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
    mfa = {async_module, :before_cancel, 2}

    case Rephex.Util.call_optional(mfa, [socket, reason], {:continue, socket}) do
      {:continue, %Socket{} = socket} ->
        Handler.cancel_async_by_action(socket, async_module, reason)

      {:abort, %Socket{} = socket} ->
        socket
    end
  end
end
