defmodule RephexTest.Fixture.AsyncActionStateful.State do
  alias Phoenix.LiveView.AsyncResult
  import Rephex.State.Assigns

  @type t :: %{
          last_start_payload: map(),
          last_resolve_result: term(),
          result_single: %AsyncResult{},
          result_multi: %{term() => %AsyncResult{}}
        }

  @initial_state %{
    last_start_payload: %{},
    last_resolve_result: nil,
    result_single: %AsyncResult{},
    result_multi: %{}
  }

  use Rephex.State, initial_state: @initial_state

  def initial_state_for_model, do: @initial_state

  def extract(state) do
    state
    |> Enum.filter(fn {k, _} -> Map.has_key?(@initial_state, k) end)
    |> Map.new()
  end

  def set_last_start_payload(socket, payload) do
    put_state_in(socket, [:last_start_payload], payload)
  end

  def set_last_resolve_result(socket, result) do
    put_state_in(socket, [:last_resolve_result], result)
  end
end
