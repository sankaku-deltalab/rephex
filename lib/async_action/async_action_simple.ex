defmodule Rephex.AsyncAction.Simple do
  alias Phoenix.LiveView.{Socket, AsyncResult}
  import Rephex.State.Assigns

  @type loading_status() :: any()
  @type result() :: any()
  @type exit_reason() :: any()
  @type loading_updater() :: (loading_status() -> nil)

  @callback start_async(
              state :: map(),
              payload :: map(),
              progress :: loading_updater()
            ) :: result()

  defmacro __using__([async_keys: async_keys] = _opt) do
    quote do
      @behaviour Rephex.AsyncAction.Base
      @behaviour Rephex.AsyncAction.Simple

      @spec start(Socket.t(), map()) :: any()
      def start(socket, payload) do
        Rephex.AsyncAction.Simple.start_async_action(
          socket,
          payload,
          __MODULE__,
          unquote(async_keys)
        )
      end

      @spec cancel(Socket.t(), any()) :: Socket.t()
      def cancel(%Socket{} = socket, reason \\ {:shutdown, :cancel}) do
        Rephex.AsyncAction.Simple.cancel_async_action(
          socket,
          __MODULE__,
          reason,
          unquote(async_keys)
        )
      end

      def receive_message(%Socket{} = socket, loading_progress) do
        Rephex.AsyncAction.Simple.receive_message(
          socket,
          loading_progress,
          unquote(async_keys)
        )
      end

      def resolve(%Socket{} = socket, result) do
        Rephex.AsyncAction.Simple.resolve(
          socket,
          result,
          unquote(async_keys)
        )
      end
    end
  end

  def start_async_action(
        %Socket{parent_pid: parent_pid} = socket,
        payload,
        async_simple_module,
        async_keys
      )
      when is_atom(async_simple_module) do
    if parent_pid != nil,
      do: raise("Use this function only in LiveView (root).")

    case get_state_in(socket, async_keys) do
      %AsyncResult{loading: nil} ->
        state = Rephex.State.Assigns.get_state(socket)
        lv_pid = self()
        upd_progress = fn msg -> send(lv_pid, {Rephex.AsyncAction, async_simple_module, msg}) end
        fun_raw = &async_simple_module.start_async/3
        fun_for_async = fn -> fun_raw.(state, payload, upd_progress) end

        Phoenix.LiveView.start_async(socket, async_simple_module, fun_for_async)

      _ ->
        socket
    end
  end

  def cancel_async_action(
        %Socket{parent_pid: parent_pid} = socket,
        async_simple_module,
        reason,
        async_keys
      )
      when is_atom(async_simple_module) do
    if parent_pid != nil,
      do: raise("Use this function only in LiveView (root).")

    with %AsyncResult{loading: loading} when loading != nil <- get_state_in(socket, async_keys) do
      socket
      |> update_state_in(
        async_keys,
        &AsyncResult.failed(&1, reason)
      )
      |> Phoenix.LiveView.cancel_async(async_simple_module, reason)
    else
      _ ->
        socket
    end
  end

  def resolve(%Socket{} = socket, result, async_keys) do
    case result do
      {:ok, success_result} ->
        socket
        |> update_state_in(
          async_keys,
          &AsyncResult.ok(&1, success_result)
        )

      {:exit, reason} ->
        socket
        |> update_state_in(
          async_keys,
          &AsyncResult.failed(&1, reason)
        )
    end
  end

  def receive_message(%Socket{} = socket, loading_progress, async_keys) do
    socket
    |> Rephex.State.Assigns.update_state_in(
      async_keys,
      &AsyncResult.loading(&1, loading_progress)
    )
  end
end
