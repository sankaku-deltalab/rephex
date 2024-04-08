# Rephex

**Rephex**: Target to include the Power of [Redux-toolkit](https://redux-toolkit.js.org) to Phoenix LiveView.

By integrating Rephex into your Phoenix LiveView projects, you unlock a suite of capabilities designed to enhance the structure, readability, and maintainability of your code:

- **Decouple State Management from Views**: Achieve a clean separation between your application's state and its presentation layer, allowing for more manageable codebases and clearer state transitions.
- **Child-Driven Assigns**: Empower smaller components to define their required assigns, streamlining data flow and component hierarchy for a more intuitive development experience.
- **Clear State Demarcation**: Easily distinguish between global application states and the ephemeral local states of individual components, such as form inputs, enhancing the clarity of your component architecture.
- **Simplified Asynchronous Operations**: Rephex simplifies the handling of asynchronous operations, making it easier to manage data fetching, processing, and more with minimal boilerplate.


## State Example

<!-- MODULEDOC -->

```elixir
defmodule RephexPgWeb.State do
  @initial_state %{
    count: 0,
  }

  use Rephex.State, initial_state: @initial_state

  def add_count(socket, %{amount: amount} = _payload) when is_integer(amount) do
    # You can use `update_state`, `update_state_in` and `put_state_in` to update state
    update_state_in(socket, [:count], &(&1 + amount))
  end
end
```

```elixir
defmodule RephexPgWeb.AccountLive.Index do
  alias RephexPgWeb.State
  use RephexPgWeb, :live_view
  use Rephex.LiveView

  alias Phoenix.LiveView.{AsyncResult, Socket}
  alias RephexPgWeb.AccountLive.ComponentA

  @impl true
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket |> State.init()}
  end

  @impl true
  def handle_event("add_count", %{"amount" => amount}, %Socket{} = socket) do
    {am, _} = Integer.parse(amount)

    {:noreply, socket |> State.add_count(%{amount: am})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Count: <%= @rpx.count %></div>
    <button class="border-2" phx-click="add_count" phx-value-amount={1}>
      [Add Count 1]
    </button>
    <.live_component module={ComponentA} id="cmp_a" rpx={@rpx} />
    """
  end
end
```

```elixir
defmodule RephexPgWeb.AccountLive.ComponentA do
  use RephexPgWeb, :live_component
  use Rephex.LiveComponent

  alias Phoenix.LiveView.Socket

  @initial_local_state %{}

  @impl true
  def mount(%Socket{} = socket) do
    {:ok, socket |> assign(@initial_local_state)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> propagate_rephex(assigns)}
  end

  @impl true
  def handle_event("add_count", %{"amount" => amount}, %Socket{} = socket) do
    {am, _} = Integer.parse(amount)

    {:noreply,
     socket
     |> call_in_root(fn socket ->
       State.add_count(socket, %{amount: am})
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <button class="border-2" phx-click="add_count" phx-value-amount={2} phx-target={@myself}>
      [Add Count 2]
    </button>
    """
  end
end
```

<!-- MODULEDOC -->

## AsyncAction Example

```elixir
defmodule RephexPgWeb.State do
  alias Phoenix.LiveView.AsyncResult

  @initial_state %{
    count: 0,
    # AsyncAction requires AsyncResult.
    double_value: AsyncResult.ok(0),
    add_twice_async: AsyncResult.ok(0),
    # AsyncActionMulti requires map will contain AsyncResult.
    delayed_add_multi: %{}
  }

  use Rephex.State, initial_state: @initial_state

  def add_count(socket, %{amount: amount} = _payload) when is_integer(amount) do
    # You can use `update_state`, `update_state_in` and `put_state_in` to update state
    update_state_in(socket, [:count], &(&1 + amount))
  end
end
```

```elixir
defmodule RephexPgWeb.State.HeavyDoubleAsync do
  use Rephex.AsyncAction, result_path: [:double_value]

  @impl true
  def initial_progress(_path, _payload) do
    # optional but recommended
    # `start/4` apply this progress synchronously.
    # AsyncResult.loading will be `{progress, _meta_values}` before start_async.
    {0, 100}
  end

  @impl true
  def start_async(_state, _path, %{amount: amount} = _payload, progress) do
    # required
    # This function will be passed to Phoenix's `start_async`.
    max = 100
    progress.({0, max})

    1..max
    |> Enum.each(fn i ->
      :timer.sleep(2)
      progress.({i, max})
    end)

    amount * 2
    # AsyncAction will call `AsyncResult.ok(prev, amount)` on `handle_event`.
  end
end
```

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

