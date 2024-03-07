defmodule RephexTest.Fixture.AsyncActionStateful.ActionMulti do
  use Rephex.AsyncActionMulti,
    result_map_path: [:result_2]

  alias RephexTest.Fixture.AsyncActionStateful.Action

  @impl true
  defdelegate initial_progress(result_path, payload), to: Action

  @impl true
  defdelegate before_start(socket, result_path, payload), to: Action

  @impl true
  defdelegate after_resolve(socket, result_path, result), to: Action

  @impl true
  defdelegate generate_failed_value(result_path, reason), to: Action

  @impl true
  defdelegate start_async(state, result_path, payload, update_progress), to: Action
end
