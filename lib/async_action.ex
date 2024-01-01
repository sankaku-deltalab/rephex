defmodule Rephex.AsyncAction do
  alias Phoenix.LiveView.Socket

  @callback before_async(socket :: Socket.t(), payload :: map()) ::
              {:continue, Socket.t()} | {:abort, Socket.t()}
  @callback start_async(state :: map(), payload :: map(), send_msg :: (any() -> any())) :: any()
  @callback resolve(socket :: Socket.t(), result :: {:ok, any()} | {:exit, any()}) :: Socket.t()
  @callback receive_message(socket :: Socket.t(), message :: any()) :: Socket.t()
  @callback canceled(socket :: Socket.t(), reason :: any()) :: Socket.t()

  defmacro __using__([slice: slice_module] = _opt) do
    quote do
      @behaviour Rephex.AsyncAction
      @__slice_module unquote(slice_module)

      # NOTE: `@type payload` must be defined.

      @spec start(Socket.t(), payload()) :: any()
      def start(socket, payload) do
        Rephex.AsyncAction.start_async_action(socket, payload,
          slice_module: @__slice_module,
          async_module: __MODULE__
        )
      end

      @spec cancel(Socket.t(), any()) :: Socket.t()
      def cancel(%Socket{} = socket, reason \\ {:shutdown, :cancel}) do
        Rephex.AsyncAction.cancel_async_action(socket,
          slice_module: @__slice_module,
          reason: reason
        )
      end
    end
  end

  def start_async_action(socket, payload, slice_module: slice_module, async_module: async_module)
      when is_atom(slice_module) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must start async on propagated state.")

    case async_module.before_async(socket, payload) do
      {:continue, %Socket{} = socket} ->
        slice_state = Rephex.State.Support.get_slice!(socket, slice_module)
        lv_pid = self()
        send_msg = fn msg -> send(lv_pid, {Rephex.AsyncAction, async_module, msg}) end
        fun_raw = &async_module.start_async/3
        fun_for_async = fn -> fun_raw.(slice_state, payload, send_msg) end

        Phoenix.LiveView.start_async(socket, async_module, fun_for_async)

      {:abort, %Socket{} = socket} ->
        socket
    end
  end

  def cancel_async_action(%Socket{} = socket, slice_module: slice_module, reason: reason)
      when is_atom(slice_module) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must cancel async on propagated state.")

    socket
    |> Phoenix.LiveView.cancel_async(slice_module, reason)
    |> slice_module.canceled(reason)
  end
end
