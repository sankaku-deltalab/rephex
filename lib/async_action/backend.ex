defmodule Rephex.AsyncAction.Backend do
  alias Phoenix.LiveView.{Socket, AsyncResult}

  import Rephex.State.Assigns
  alias Rephex.Api.{LiveViewApi, KernelApi, SystemApi}

  @type loading :: {any(), %{last_update_time: integer() | nil}}

  @doc """
  `YourAction.start(socket, ...)` call this.
  """
  def start(%Socket{} = socket, {_action_module, result_path} = async_key, payload, opts) do
    socket = socket |> put_async_result_if_not_exist(result_path)

    if should_start?(socket, async_key, opts) do
      start_internal(socket, async_key, payload)
    else
      socket
    end
  end

  defp should_start?(socket, {_action_module, result_path} = _async_key, opts) do
    restart_if_running = Keyword.get(opts, :restart_if_running, false)

    case get_state_in(socket, result_path) do
      %AsyncResult{loading: nil} -> true
      %AsyncResult{loading: _} -> restart_if_running
    end
  end

  defp start_internal(%Socket{} = socket, {action_module, result_path} = async_key, payload) do
    initial_progress = call_initial_progress(result_path, payload, action_module)
    async_fun = generate_start_async_fun(socket, async_key, payload)
    async_name = gen_start_async_name(async_key)
    meta = %{last_update_time: nil}

    socket
    |> call_before_start(result_path, payload, action_module)
    |> update_loading_status!(async_key, progress: initial_progress, meta: meta)
    |> LiveViewApi.start_async(async_name, async_fun)
  end

  defp generate_start_async_fun(
         %Socket{} = socket,
         {action_module, result_path} = async_key,
         payload
       ) do
    state = Rephex.State.Assigns.get_state(socket)
    lv_pid = self()

    update_progress =
      &KernelApi.send(
        lv_pid,
        gen_update_progress_message(async_key, &1)
      )

    async_fun_raw = &action_module.start_async/4
    fn -> async_fun_raw.(state, result_path, payload, update_progress) end
  end

  @doc """
  `YourAction.cancel(socket, ...)` call this.
  """
  def cancel(%Socket{} = socket, async_key, reason) do
    async_name = gen_start_async_name(async_key)

    socket
    |> LiveViewApi.cancel_async(async_name, reason)
  end

  @doc """
  `LiveView.handle_info(..., socket)` call this.
  """
  def update_progress(%Socket{} = socket, {action_module, _result_path} = async_key, progress) do
    now = SystemApi.monotonic_time(:millisecond)
    option = call_options(action_module)
    throttle = Map.get(option, :throttle, 0)
    meta = %{last_update_time: now}

    if can_update_progress?(socket, async_key, now, throttle) do
      update_loading_status!(socket, async_key, progress: progress, meta: meta)
    else
      socket
    end
  end

  defp can_update_progress?(socket, {_m, result_path}, now, throttle) do
    # Ignore update progress if not running
    # Ignore update if throttle is not overed
    case get_state_in(socket, result_path) do
      %AsyncResult{loading: nil} -> false
      %AsyncResult{loading: {_, %{last_update_time: nil}}} -> true
      %AsyncResult{loading: {_, %{last_update_time: t}}} when now - t >= throttle -> true
      _ -> false
    end
  end

  @doc """
  `LiveView.handle_async(..., result, socket)` call this.
  """
  def resolve(%Socket{} = socket, {action_module, result_path} = async_key, result) do
    case result do
      {:ok, success_result} ->
        socket
        |> set_async_as_ok!(async_key, success_result)

      {:exit, reason} ->
        failed_value = call_generate_failed_value(result_path, reason, action_module)

        socket
        |> set_async_as_failed!(async_key, failed_value)
    end
    |> call_after_resolve(result_path, result, action_module)
  end

  # Optional callbacks

  defp call_initial_progress(result_path, payload, action_module) do
    mfa = {action_module, :initial_progress, 2}
    Rephex.Util.call_optional(mfa, [result_path, payload], true)
  end

  defp call_before_start(socket, result_path, payload, action_module) do
    mfa = {action_module, :before_start, 3}
    Rephex.Util.call_optional(mfa, [socket, result_path, payload], socket)
  end

  defp call_after_resolve(socket, result_path, result, action_module) do
    mfa = {action_module, :after_resolve, 3}
    Rephex.Util.call_optional(mfa, [socket, result_path, result], socket)
  end

  defp call_generate_failed_value(result_path, reason, action_module) do
    mfa = {action_module, :generate_failed_value, 2}
    Rephex.Util.call_optional(mfa, [result_path, reason], reason)
  end

  defp call_options(action_module) do
    mfa = {action_module, :options, 0}
    Rephex.Util.call_optional(mfa, [], %{})
  end

  # Generate process message

  defp gen_update_progress_message({action_module, result_path}, progress) do
    {Rephex.AsyncAction.Backend, :update_progress, {action_module, result_path}, progress}
  end

  defp gen_start_async_name({action_module, result_path}) do
    {Rephex.AsyncAction.Backend, :start_async, {action_module, result_path}}
  end

  # Update result

  defp set_async_as_ok!(
         %Socket{} = socket,
         {_action_module, result_path},
         result
       ) do
    socket
    |> update_state_in(result_path, &AsyncResult.ok(&1, result))
  end

  defp set_async_as_failed!(
         %Socket{} = socket,
         {_action_module, result_path},
         result
       ) do
    socket
    |> update_state_in(result_path, &AsyncResult.failed(&1, result))
  end

  defp update_loading_status!(
         %Socket{} = socket,
         {_action_module, result_path},
         progress: progress,
         meta: meta
       ) do
    socket
    |> update_state_in(result_path, &AsyncResult.loading(&1, {progress, meta}))
  end

  defp put_async_result_if_not_exist(socket, result_path) do
    case get_state_in(socket, result_path) do
      nil ->
        socket
        |> put_state_in(result_path, %AsyncResult{})

      _ ->
        socket
    end
  end
end
