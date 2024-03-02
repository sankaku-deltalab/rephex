defmodule RephexTest.Fixture.AsyncActionStateful.State do
  alias Phoenix.LiveView.AsyncResult
  import Rephex.State.Assigns

  @type t :: %{
          before_start_count: integer(),
          after_resolve_count: integer(),
          result_1: %AsyncResult{}
        }

  @initial_state %{
    before_start_count: 0,
    after_resolve_count: 0,
    result_1: %AsyncResult{}
  }

  use Rephex.State, initial_state: @initial_state

  def initial_state_for_model, do: @initial_state

  def extract(state) do
    state
    |> Enum.filter(fn {k, _} -> Map.has_key?(@initial_state, k) end)
    |> Map.new()
  end

  def add_before_start_count(socket, amount) do
    update_state_in(socket, [:before_start_count], &(&1 + amount))
  end

  def add_after_resolve_count(socket, amount) do
    update_state_in(socket, [:after_resolve_count], &(&1 + amount))
  end
end
