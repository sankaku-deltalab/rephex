# Rephex

Rephex is Redux-toolkit in Phenix LiveView.

## Example:

```elixir
defmodule RephexUser.State do
  alias RephexUser.Slice
  use Rephex.State, slices: [Slice.CounterSlice]
end
```

```elixir
defmodule RephexUser.Slice.CounterSlice do
  @behaviour Rephex.Slice
  alias Phoenix.LiveView.Socket
  alias RephexUser.Slice.CounterSlice.AsyncAddCount

  defmodule State do
    defstruct count: 0
    @type t :: %State{count: integer()}

    @spec add_count(t(), integer()) :: t()
    def add_count(%__MODULE__{} = state, amount) when is_integer(amount) do
      %{state | count: state.count + amount}
    end
  end

  defmodule Support do
    use Rephex.Slice.Support, struct: State, name: :counter3
  end

  @impl true
  @spec init(Socket.t()) :: Socket.t()
  def init(%Socket{} = socket) do
    Support.init_slice(socket, %State{})
  end

  @impl true
  @spec async_modules() :: [atom()]
  def async_modules(), do: [AsyncAddCount]

  # Action

  @spec count_up(Socket.t(), %{}) :: Socket.t()
  def count_up(%Socket{} = socket, _payload) do
    Support.update_slice(socket, &State.add_count(&1, 1))
  end

  @spec add_count(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count(%Socket{} = socket, %{amount: am}) when is_integer(am) do
    Support.update_slice(socket, &State.add_count(&1, am))
  end

  # Async action

  @spec add_count_async(Socket.t(), %{amount: integer()}) :: Socket.t()
  def add_count_async(%Socket{} = socket, %{amount: _am} = payload) do
    AsyncAddCount.start(socket, payload)
  end

  # Selector

  @spec count(%{counter3: map()}) :: integer()
  def count(root) do
    root
    |> Support.slice_in_root()
    |> then(fn %State{count: c} -> c end)
  end
end

defmodule RephexUser.Slice.CounterSlice.AsyncAddCount do
  @behaviour Rephex.AsyncAction

  alias RephexUser.Slice.CounterSlice
  alias RephexUser.Slice.CounterSlice.Support
  import Phoenix.LiveComponent
  alias Phoenix.LiveView.Socket
  # alias Phoenix.LiveView.AsyncResult

  @impl true
  @spec start(Socket.t(), %{amount: integer()}) :: Socket.t()
  def start(%Socket{} = socket, %{amount: am}) do
    Support.start_async(socket, __MODULE__, fn _state ->
      :timer.sleep(1000)
      am
    end)
  end

  @impl true
  def resolve(%Socket{} = socket, result) do
    case result do
      {:ok, amount} when is_integer(amount) -> CounterSlice.add_count(socket, %{amount: amount})
      {:exit, _reason} -> socket
    end
  end
end
```

```elixir
defmodule RephexUserWeb.UserLive.Index do
  use RephexUserWeb, :live_view
  alias Phoenix.LiveView.Socket
  alias RephexUser.State
  alias RephexUser.Slice.CounterSlice

  # Init at root component
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, State.init(socket)}
  end

  # Update Rephex state by event
  def handle_event("add_count", %{"amount" => am}, socket) when is_bitstring(am) do
    am = am |> String.to_integer()
    socket = socket |> CounterSlice.add_count(%{amount: am})
    {:noreply, socket}
  end

  def handle_event("add_2_async", _params, socket) do
    socket = socket |> CounterSlice.add_count_async(%{amount: 2})
    {:noreply, socket}
  end

  def handle_async(name, result, socket) do
    {:noreply, State.resolve_async(socket, name, result)}
  end
end
```

```heex
<div>
  <p>Count: <%= RephexUser.Slice.CounterSlice.count(@__rephex__) %></p>
  <button phx-click="add_count" phx-value-amount="10">[Add 10]</button>
  <button phx-click="add_2_async">[Add 2 async]</button>
</div>
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

