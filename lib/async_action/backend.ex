defmodule Rephex.AsyncAction.Backend do
  alias Phoenix.LiveView.{Socket, AsyncResult}

  import Rephex.State.Assigns
  alias Rephex.AsyncAction.Meta
  alias Rephex.Api.{LiveViewApi, KernelApi, SystemApi}

  @doc """
  `YourAction.start(socket, ...)` call this.
  """
  def start(%Socket{} = socket, {action_module, result_path}, payload) do
    socket = socket |> put_async_result_if_not_exist(result_path)

    case get_state_in(socket, result_path) do
      %AsyncResult{loading: nil} ->
        state = Rephex.State.Assigns.get_state(socket)
        initial_progress = call_initial_progress(result_path, payload, action_module)

        lv_pid = self()

        update_progress =
          &KernelApi.send(
            lv_pid,
            gen_update_progress_message({action_module, result_path}, &1)
          )

        async_fun_raw = &action_module.start_async/4
        async_fun = fn -> async_fun_raw.(state, result_path, payload, update_progress) end

        now = SystemApi.monotonic_time(:millisecond)

        socket
        |> call_before_start(result_path, payload, action_module)
        |> update_loading_status!({action_module, result_path},
          progress: initial_progress,
          now: now
        )
        |> LiveViewApi.start_async(
          gen_start_async_name({action_module, result_path}),
          async_fun
        )

      %AsyncResult{} ->
        socket
    end
  end

  @doc """
  `YourAction.cancel(socket, ...)` call this.
  """
  def cancel(%Socket{} = socket, {action_module, result_path}, reason) do
    socket
    |> LiveViewApi.cancel_async(
      gen_start_async_name({action_module, result_path}),
      reason
    )
  end

  @doc """
  `LiveView.handle_info(..., socket)` call this.
  """
  def update_progress(%Socket{} = socket, {action_module, result_path} = meta_key, progress) do
    now = SystemApi.monotonic_time(:millisecond)
    last_time = Meta.get_last_progress_updated_time(socket, meta_key)
    option = call_option(action_module)
    throttle = Map.get(option, :throttle, -1)

    throttle_ok = last_time == nil or now - last_time > throttle

    with true <- throttle_ok,
         %AsyncResult{loading: v} when v != nil <- get_state_in(socket, result_path) do
      update_loading_status!(socket, meta_key, progress: progress, now: now)
    else
      _ ->
        socket
    end
  end

  defp update_loading_status!(
         %Socket{} = socket,
         {_action_module, result_path} = meta_key,
         progress: progress,
         now: now
       ) do
    socket
    |> Meta.notify_progress_updated(meta_key, now)
    |> update_state_in(result_path, &AsyncResult.loading(&1, progress))
  end

  @doc """
  `LiveView.handle_async(..., result, socket)` call this.
  """
  def resolve(%Socket{} = socket, {action_module, result_path}, result) do
    case result do
      {:ok, success_result} ->
        socket
        |> update_state_in(result_path, &AsyncResult.ok(&1, success_result))
        |> call_after_resolve(result_path, result, action_module)

      {:exit, reason} ->
        failed_value = call_generate_failed_value(result_path, reason, action_module)

        socket
        |> update_state_in(result_path, &AsyncResult.failed(&1, failed_value))
        |> call_after_resolve(result_path, result, action_module)
    end
  end

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

  defp call_option(action_module) do
    mfa = {action_module, :option, 0}
    Rephex.Util.call_optional(mfa, [], %{})
  end

  defp gen_update_progress_message({action_module, result_path}, progress) do
    {Rephex.AsyncAction.Backend, :update_progress, {action_module, result_path}, progress}
  end

  defp gen_start_async_name({action_module, result_path}) do
    {Rephex.AsyncAction.Backend, :start_async, {action_module, result_path}}
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
