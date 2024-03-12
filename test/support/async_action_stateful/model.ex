defmodule RephexTest.Fixture.AsyncActionStateful.Model do
  import ExUnit.Assertions
  alias Phoenix.LiveView.AsyncResult
  alias RephexTest.Fixture.AsyncActionStateful.State

  @type result_path :: [term()]
  @type async_key :: {module(), result_path()}

  @type t :: %__MODULE__{
          running_items: MapSet.t(async_key()),
          state: State.t()
        }
  defstruct [:running_items, :state]

  def new() do
    %__MODULE__{running_items: MapSet.new(), state: State.initial_state_for_model()}
  end

  def start_single(model, action_module, payload) do
    result_path = [:result_single]
    start_internal(model, action_module, result_path, payload)
  end

  def start_multi(model, {action_module, key}, payload) do
    state = model.state
    result_path = [:result_multi, key]

    # Put AsyncResult if not exist
    state =
      case get_in(state, result_path) do
        nil -> put_in(state, result_path, %AsyncResult{})
        _ -> state
      end

    model = %__MODULE__{model | state: state}

    start_internal(model, action_module, result_path, payload)
  end

  defp start_internal(model, action_module, result_path, payload) do
    state = model.state
    item = {action_module, result_path}

    case get_in(state, result_path) do
      %AsyncResult{loading: nil} ->
        running_items = MapSet.put(model.running_items, item)
        initial_progress = action_module.initial_progress(result_path, payload)

        state =
          state
          |> update_in(result_path, &AsyncResult.loading(&1, initial_progress))
          |> put_in([:last_start_payload], payload)

        %__MODULE__{model | running_items: running_items, state: state}

      _ ->
        model
    end
  end

  def async_process_update_progress(model, {_action_module, result_path}, progress) do
    # Ignore update progress if not running
    state =
      case get_in(model.state, result_path) do
        %AsyncResult{loading: nil} ->
          model.state

        %AsyncResult{} ->
          update_in(model.state, result_path, &AsyncResult.loading(&1, progress))

        _ ->
          model.state
      end

    %__MODULE__{model | state: state}
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
end
