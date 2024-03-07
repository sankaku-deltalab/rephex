defmodule RephexTest.Fixture.AsyncActionStateful.ModelMulti do
  import ExUnit.Assertions
  alias Phoenix.LiveView.AsyncResult
  alias RephexTest.Fixture.AsyncActionStateful.{State, Action}

  defstruct [:running_payloads, :state]

  def new() do
    %__MODULE__{running_payloads: %{}, state: State.initial_state_for_model()}
  end

  def start(model, result_path, payload) do
    state = model.state

    state =
      case get_in(state, result_path) do
        nil -> put_in(state, result_path, %AsyncResult{})
        _ -> state
      end

    case get_in(state, result_path) do
      %AsyncResult{loading: nil} ->
        running_payloads = model.running_payloads |> Map.put(result_path, payload)
        initial_progress = Action.initial_progress(result_path, payload)

        state =
          state
          |> update_in(result_path, fn async_result ->
            AsyncResult.loading(async_result, initial_progress)
          end)
          |> update_in([:before_start_count], &(&1 + payload.before_start_amount))

        %__MODULE__{model | running_payloads: running_payloads, state: state}

      _ ->
        model
    end
  end

  def async_process_update_progress(model, result_path, progress) do
    state =
      update_in(model.state, result_path, fn async_result ->
        AsyncResult.loading(async_result, progress)
      end)

    %__MODULE__{model | state: state}
  end

  def async_process_resolved(model, result_path, result) do
    assert Map.has_key?(model.running_payloads, result_path)

    running_payloads =
      model.running_payloads
      |> Map.delete(result_path)

    state =
      update_in(model.state, result_path, fn async_result ->
        case result do
          {:ok, value} ->
            AsyncResult.ok(async_result, value)

          {:exit, reason} ->
            AsyncResult.failed(async_result, Action.generate_failed_value(result_path, reason))
        end
      end)

    state =
      case result do
        {:ok, value} ->
          update_in(state, [:after_resolve_count], &(&1 + value.after_resolve))

        _ ->
          state
      end

    %__MODULE__{model | state: state, running_payloads: running_payloads}
  end

  def cancel(model, _result_path, _reason) do
    model
  end
end
