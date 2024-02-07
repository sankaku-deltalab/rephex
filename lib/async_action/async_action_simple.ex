defmodule Rephex.AsyncAction.Simple.Meta do
  alias Phoenix.LiveView.Socket

  defstruct last_loading_update_time: nil

  @meta_root :__rephex_meta_async_action_simple

  @spec update_loading_time(%__MODULE__{}) :: %__MODULE__{}
  def update_loading_time(%__MODULE__{} = meta) do
    now = System.monotonic_time(:millisecond)

    %__MODULE__{meta | last_loading_update_time: now}
  end

  @spec init_state(Socket.t()) :: Socket.t()
  def init_state(%Socket{} = socket) do
    socket
    |> Rephex.State.Assigns.put_state(@meta_root, %{})
  end

  @spec reset_meta(Socket.t(), module()) :: Socket.t()
  def reset_meta(%Socket{} = socket, async_module) when is_atom(async_module) do
    socket
    |> Rephex.State.Assigns.update_state_in(
      [@meta_root, async_module],
      fn _ -> %__MODULE__{} end
    )
  end

  @spec update_loading_time_in_socket(Socket.t(), module()) :: Socket.t()
  def update_loading_time_in_socket(%Socket{} = socket, async_module)
      when is_atom(async_module) do
    socket
    |> Rephex.State.Assigns.update_state_in(
      [@meta_root],
      fn meta -> Map.update!(meta, async_module, &update_loading_time/1) end
    )
  end

  @spec get_meta(Socket.t(), module()) :: %__MODULE__{}
  def get_meta(%Socket{} = socket, async_module) when is_atom(async_module) do
    Rephex.State.Assigns.get_state_in(socket, [@meta_root, async_module])
  end
end

defmodule Rephex.AsyncAction.Simple do
  alias Phoenix.LiveView.{Socket, AsyncResult}
  import Rephex.State.Assigns
  alias Rephex.AsyncAction.Handler
  alias Rephex.AsyncAction.Simple.Meta

  @type loading_state() :: any()
  @type success_result() :: any()
  @type exit_reason() :: any()
  @type loading_updater() :: (loading_state() -> nil)

  @callback initial_loading_state(
              state :: map(),
              payload :: map()
            ) :: loading_state()

  @callback start_async(
              state :: map(),
              payload :: map(),
              progress :: loading_updater()
            ) :: success_result()

  @callback after_async(
              socket :: Socket.t(),
              result :: {:ok, success_result()} | {:exit, exit_reason()}
            ) :: Socket.t()

  @callback option() :: %{optional(:throttle) => pos_integer()}

  @doc """
  If there is a possibility that the exit reason returns a value
  that cannot be included in socket.assigns, you need to transform the exit reason.
  """
  @callback convert_exit_reason(reason :: any()) :: any()

  @optional_callbacks initial_loading_state: 2,
                      convert_exit_reason: 1,
                      after_async: 2,
                      option: 0

  defmacro __using__(opt) do
    default_payload_type =
      quote do
        map()
      end

    default_cancel_reason_type =
      quote do
        any()
      end

    async_keys = Keyword.fetch!(opt, :async_keys)
    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @behaviour Rephex.AsyncAction.Simple

      @spec start(Socket.t(), unquote(payload_type)) :: any()
      def start(socket, payload) do
        Rephex.AsyncAction.Simple.start_async_action(
          socket,
          payload,
          __MODULE__,
          unquote(async_keys)
        )
      end

      @spec cancel(Socket.t(), unquote(cancel_reason_type)) :: Socket.t()
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
          __MODULE__,
          loading_progress,
          unquote(async_keys)
        )
      end

      def resolve(%Socket{} = socket, result) do
        Rephex.AsyncAction.Simple.resolve(
          socket,
          __MODULE__,
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
        upd_progress = &Handler.send_message_from_action(lv_pid, async_simple_module, &1)
        fun_raw = &async_simple_module.start_async/3
        fun_for_async = fn -> fun_raw.(state, payload, upd_progress) end

        mfa = {async_simple_module, :initial_loading_state, 2}
        initial_loading_state = Rephex.Util.call_optional(mfa, [state, payload], true)

        socket
        |> Meta.reset_meta(async_simple_module)
        |> update_state_in(async_keys, &AsyncResult.loading(&1, initial_loading_state))
        |> Handler.start_async_by_action(async_simple_module, fun_for_async)

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
      |> Handler.cancel_async_by_action(async_simple_module, reason)
    else
      _ ->
        socket
    end
  end

  def resolve(%Socket{} = socket, async_simple_module, result, async_keys)
      when is_atom(async_simple_module) do
    after_async_mfa = {async_simple_module, :after_async, 2}

    case result do
      {:ok, success_result} ->
        socket
        |> update_state_in(
          async_keys,
          &AsyncResult.ok(&1, success_result)
        )

      {:exit, reason} ->
        mfa = {async_simple_module, :convert_exit_reason, 1}
        reason = Rephex.Util.call_optional(mfa, [reason], reason)

        socket
        |> update_state_in(
          async_keys,
          &AsyncResult.failed(&1, reason)
        )
    end
    |> then(&Rephex.Util.call_optional(after_async_mfa, [&1, result], &1))
  end

  def receive_message(%Socket{} = socket, async_simple_module, loading_progress, async_keys) do
    now = System.monotonic_time(:millisecond)

    %Meta{last_loading_update_time: last_time} = Meta.get_meta(socket, async_simple_module)

    mfa = {async_simple_module, :option, 0}
    option = Rephex.Util.call_optional(mfa, [], %{})
    throttle = Map.get(option, :throttle, -1)

    if last_time == nil or now - last_time > throttle do
      socket
      |> Meta.update_loading_time_in_socket(async_simple_module)
      |> Rephex.State.Assigns.update_state_in(
        async_keys,
        &AsyncResult.loading(&1, loading_progress)
      )
    else
      socket
    end
  end
end
