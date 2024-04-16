defmodule Rephex.AsyncAction.Base do
  alias Phoenix.LiveView.Socket

  # Path to target AsyncResult
  @type result_path :: [term()]
  @type state :: map()
  @type payload :: map()
  @type progress :: any()
  @type success_result :: any()
  @type exit_reason :: any()
  @type failed_value :: any()

  @doc """
  Get initial progress. This value will be set synchronously before the async action starts.
  """
  @callback initial_progress(result_path(), payload()) :: progress()

  @doc """
  Before the async action starts, this callback will be called.
  """
  @callback before_start(Socket.t(), result_path(), payload()) :: Socket.t()

  @doc """
  After the async action is resolved, this callback will be called.
  """
  @callback after_resolve(
              Socket.t(),
              result_path(),
              {:ok, success_result()} | {:exit, exit_reason()}
            ) :: Socket.t()

  @doc """
  Generate failed value. This value will be set to AsyncResult via `AsyncResult.failed/2`.
  """
  @callback generate_failed_value(result_path(), exit_reason()) :: failed_value()

  @doc """
  Start async action.
  """
  @callback start_async(
              state(),
              result_path(),
              payload(),
              (progress() -> nil)
            ) :: success_result()

  @doc """
  This callback will be implemented by __using__.
  """
  @callback options() :: %{optional(:throttle) => non_neg_integer()}

  @optional_callbacks initial_progress: 2,
                      before_start: 3,
                      after_resolve: 3,
                      generate_failed_value: 2
end
