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

  @callback initial_progress(result_path(), payload()) :: progress()
  @callback before_start(Socket.t(), result_path(), payload()) :: Socket.t()
  @callback after_resolve(
              Socket.t(),
              result_path(),
              {:ok, success_result()} | {:exit, exit_reason()}
            ) :: Socket.t()
  @callback generate_failed_value(result_path(), exit_reason()) :: failed_value()
  @callback start_async(
              state(),
              result_path(),
              payload(),
              (progress() -> nil)
            ) :: success_result()

  @callback option() :: %{optional(:throttle) => pos_integer()}

  @optional_callbacks initial_progress: 2,
                      before_start: 3,
                      after_resolve: 3,
                      generate_failed_value: 2,
                      option: 0
end
