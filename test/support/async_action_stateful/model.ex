defmodule RephexTest.Fixture.AsyncActionStateful.Model do
  import ExUnit.Assertions
  alias Phoenix.LiveView.AsyncResult
  alias RephexTest.Fixture.AsyncActionStateful.State

  @type result_path :: [term()]
  @type async_key :: {module(), result_path()}

  @type start_option :: {:restart_if_running, boolean()}
  @type module_option :: {:progress_throttle, non_neg_integer()}
  @type loading_meta :: %{last_update_time: integer()}

  @type t :: %__MODULE__{
          running_items: MapSet.t(async_key()),
          state: State.t(),
          monotonic_time_ms: integer()
        }
  defstruct [:running_items, :state, :monotonic_time_ms]

  def new() do
    %__MODULE__{
      running_items: MapSet.new(),
      state: State.initial_state_for_model(),
      monotonic_time_ms: -9999
    }
  end

  def start_single(model, action_module, payload, opts) do
    result_path = [:result_single]
    maybe_start(model, action_module, result_path, payload, opts)
  end

  def start_multi(model, {action_module, key}, payload, opts) do
    state = model.state
    result_path = [:result_multi, key]

    # Put AsyncResult if not exist
    state =
      case get_in(state, result_path) do
        nil -> put_in(state, result_path, %AsyncResult{})
        _ -> state
      end

    model = %__MODULE__{model | state: state}

    maybe_start(model, action_module, result_path, payload, opts)
  end

  defp maybe_start(model, action_module, result_path, payload, opts) do
    if should_start(model, action_module, result_path, payload, opts) do
      start_internal(model, action_module, result_path, payload, opts)
    else
      model
    end
  end

  defp should_start(model, _action_module, result_path, _payload, opts) do
    restart_if_running = Keyword.get(opts, :restart_if_running, false)

    case get_in(model.state, result_path) do
      %AsyncResult{loading: nil} -> true
      %AsyncResult{loading: _} -> restart_if_running
    end
  end

  defp start_internal(model, action_module, result_path, payload, _opts) do
    initial_progress = action_module.initial_progress(result_path, payload)

    model
    |> set_async_loading(action_module, result_path, initial_progress)
    |> add_running_item({action_module, result_path})
    |> set_last_start_payload(payload)
  end

  def async_process_update_progress(model, {action_module, result_path}, progress, time_delta) do
    # Ignore update progress if not running
    # Ignore throttle is not overed

    throttle = action_module.options().throttle
    now = model.monotonic_time_ms + time_delta

    model = model |> consume_time(time_delta)

    with %AsyncResult{loading: {_old_progress, %{last_update_time: t}}} <-
           get_in(model.state, result_path),
         true <- now - t >= throttle do
      model |> set_async_loading(action_module, result_path, progress)
    else
      _ ->
        model
    end
  end

  def async_process_resolved(model, {action_module, result_path} = key, result) do
    assert key in model.running_items

    running_items = MapSet.delete(model.running_items, key)

    state =
      update_in(model.state, result_path, fn async_result ->
        case result do
          {:ok, value} ->
            AsyncResult.ok(async_result, value)

          {:exit, reason} ->
            AsyncResult.failed(
              async_result,
              action_module.generate_failed_value(result_path, reason)
            )
        end
      end)
      |> put_in([:last_resolve_result], result)

    %__MODULE__{model | state: state, running_items: running_items}
  end

  def cancel_single(model, _action_module, _reason) do
    # Cancel async process but it not effect to state
    model
  end

  def cancel_multi(model, _action_module, _key, _reason) do
    # Cancel async process but it not effect to state
    model
  end

  defp consume_time(model, t) do
    %__MODULE__{model | monotonic_time_ms: model.monotonic_time_ms + t}
  end

  defp set_last_start_payload(model, payload) do
    state = model.state |> Map.put(:last_start_payload, payload)
    %__MODULE__{model | state: state}
  end

  defp add_running_item(model, item) do
    running_items = MapSet.put(model.running_items, item)
    %__MODULE__{model | running_items: running_items}
  end

  defp set_async_loading(model, _action_module, result_path, progress) do
    meta = %{last_update_time: model.monotonic_time_ms}

    state =
      model.state
      |> update_in(
        result_path,
        &AsyncResult.loading(&1, {progress, meta})
      )

    %__MODULE__{model | state: state}
  end
end
