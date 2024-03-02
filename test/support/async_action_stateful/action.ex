defmodule RephexTest.Fixture.AsyncActionStateful.Action do
  @type payload :: %{
          before_start_amount: integer(),
          resolve_amount: integer()
        }
  @type result :: %{resolved: integer(), after_resolve: integer()}
  @type cancel_reason :: {:shutdown, any()}
  @type progress :: {non_neg_integer(), non_neg_integer()}

  use Rephex.AsyncAction,
    result_path: [:result_1],
    payload_type: payload(),
    cancel_reason_type: cancel_reason(),
    progress_type: progress()

  alias RephexTest.Fixture.AsyncActionStateful.State

  # optional
  @impl true
  def initial_progress(_result_path, _payload) do
    {0, 1}
  end

  # optional
  @impl true
  def before_start(socket, _result_path, payload) do
    State.add_before_start_count(socket, payload.before_start_amount)
  end

  # optional
  @impl true
  def after_resolve(socket, _result_path, result) do
    case result do
      {:ok, %{after_resolve: after_resolve}} ->
        socket
        |> State.add_after_resolve_count(after_resolve)

      {:exit, _} ->
        socket
    end
  end

  # optional
  @impl true
  def generate_failed_value(_result_path, {:shutdown, why} = _reason) do
    why
  end

  @impl true
  def generate_failed_value(_result_path, reason) do
    reason
  end

  @impl true
  def start_async(state, result_path, payload, update_progress) do
    # This function will be called for call check
    {state, result_path, payload, update_progress}
  end
end
