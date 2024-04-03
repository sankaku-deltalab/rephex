# Rephex

Rephex is [Redux-toolkit](https://redux-toolkit.js.org) in Phenix LiveView.

Rephex を使うことで、

- 状態とその変更を View から分けることができる。
- 小コンポネントが必要とする assigns を親ではなく子が決めることができる。
- コンポネントにおいて、グローバルな状態とコンポネントが持つ些細なローカル状態（フォームなど）を明確に分けることができる。
- async をより簡単に扱うことができる。

## Example

<!-- MODULEDOC -->

```elixir
defmodule ExampleWeb.State do
  alias Phoenix.LiveView.{AsyncResult, Socket}

  @type t :: %{
          count: integer(),
          add_twice_async: %AsyncResult{}
        }

  @initial_state %{
    count: 0,
    # AsyncAction requires AsyncResult.
    add_twice_async: AsyncResult.ok(0),
    # AsyncActionMulti requires map will contain AsyncResult.
    delayed_add_multi: %{}
  }

  use Rephex.State, initial_state: @initial_state

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: amount} = _payload) when is_integer(amount) do
    # You can use `update_state`, `update_state_in` and `put_state_in` to update state
    update_state_in(socket, [:count], &(&1 + amount))
  end
end
```

```elixir
defmodule ExampleWeb.State.AddCountTwiceAsync do
  alias Phoenix.LiveView
  alias ExampleWeb.State

  @type payload :: %{amount: integer()}
  @type progress :: {current :: non_neg_integer(), total :: non_neg_integer()}
  @type cancel_reason :: any()

  use Rephex.AsyncAction,
    result_path: [:add_twice_async],
    # You can pass types for functions implemented in macro.
    payload_type: payload,
    cancel_reason_type: cancel_reason,
    progress_type: progress,
    # You can suppress hyper frequent progress updates by setting throttle.
    progress_throttle: 100

  @impl true
  def before_start(socket, _result_path, %{amount: _amount} = _payload) do
    # optional
    # This function will be called before `start_async`.
    socket |> LiveView.put_flash(:info, "Add twice start")
  end

  @impl true
  def initial_progress(_path, _payload) do
    # optional
    # This function will be called before `start_async` and determine the initial progress.
    # AsyncResult.loading will be `{progress, _meta_values}` before start_async.
    {0, 1}
  end

  @impl true
  def start_async(_state, _path, %{amount: amount} = _payload, progress) do
    # required
    # This function will be passed to Phoenix's `start_async`.
    max = 500
    progress.({0, max})

    1..max
    |> Enum.each(fn i ->
      :timer.sleep(2)
      progress.({i, max})
    end)

    amount
  end

  @impl true
  def after_resolve(socket, _result_path, result) do
    # optional
    # This function will be called after `start_async` is finished.
    case result do
      {:ok, amount} ->
        socket
        |> State.add_count(%{amount: amount})
        |> LiveView.put_flash(:info, "Add twice done: #{amount}")

      {:exit, _reason} ->
        socket
        |> LiveView.put_flash(:error, "Add twice failed")
    end
  end

  @impl true
  def generate_failed_value(_result_path, exit_reason) do
    # optional
    # You can customize the failed value.
    case exit_reason do
      {:shutdown, :cancel} -> "canceled by no-reason"
      {:shutdown, {:cancel, text}} when is_bitstring(text) -> "canceled by #{text}"
      _ -> "unknown reason"
    end
  end
end
```

```elixir
defmodule ExampleWeb.State.DelayedAddAsync do
  alias ExampleWeb.State

  @type payload :: %{amount: integer()}
  @type progress :: {current :: non_neg_integer(), total :: non_neg_integer()}
  @type cancel_reason :: any()

  use Rephex.AsyncActionMulti,
    result_map_path: [:delayed_add_multi],
    # You can pass types for functions implemented in macro.
    payload_type: payload,
    cancel_reason_type: cancel_reason,
    progress_type: progress

  @impl true
  def start_async(_state, _path, %{amount: amount} = _payload, _progress) do
    :timer.sleep(1000)
    amount
  end

  @impl true
  def after_resolve(socket, _result_path, result) do
    case result do
      {:ok, amount} ->
        socket
        |> State.add_count(%{amount: amount})

      {:exit, _reason} ->
        socket
    end
  end
end
```

<!-- MODULEDOC -->

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rephex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rephex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/rephex>.

