defmodule Rephex.State do
  @moduledoc """
  Define Rephex state by `use`.
  Defined state must be initialized by `init/1` in `Phoenix.LiveView.mount/3`.

  ## Example

      defmodule ExampleWeb.State do
        @type t :: %{
                count: integer(),
                add_twice_async: %AsyncResult{}
              }

        @initial_state %{
          count: 0,
        }

        use Rephex.State, initial_state: @initial_state

        def add_count(socket, %{amount: amount} = _payload) when is_integer(amount) do
          # You can use `update_state`, `update_state_in` and `put_state_in` to update state
          update_state_in(socket, [:count], &(&1 + amount))
        end
      end

      defmodule ExampleWeb.AccountLive.Index do
        use ExampleWeb, :live_view
        use Rephex.LiveView

        @impl true
        def mount(_params, _session, socket) do
          {:ok, socket |> ExampleWeb.State.init()}
        end
      end
  """
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  def init(%Socket{} = socket, %{} = initial_state) do
    socket
    |> Phoenix.Component.assign(@root, initial_state)
  end

  defmacro __using__(opt) do
    initial_state = Keyword.fetch!(opt, :initial_state)

    quote do
      import Rephex.State.Assigns

      def init(%Socket{} = socket) do
        socket |> Rephex.State.init(unquote(initial_state))
      end
    end
  end
end

defmodule Rephex.State.Assigns do
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  @doc """
  Update Rephex state.

  Example:
      def add_count(socket, %{amount: amount} = _payload) do
        update_state(socket, fn state -> %{state | count: state.count + amount} end)
      end

  """
  def update_state(%Socket{parent_pid: parent_pid}, _fun) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def update_state(%Socket{} = socket, fun) when is_function(fun, 1) do
    Phoenix.Component.update(socket, @root, fun)
  end

  @doc """
  Update Rephex state by `put_in/3`.

  Example:

      def put_value(socket, %{key: k, value: v} = _payload) do
        put_state_in(socket, [:items, k], v)
      end

  """
  def put_state_in(%Socket{parent_pid: parent_pid}, _keys, _value) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def put_state_in(%Socket{} = socket, keys, value) when is_list(keys) do
    update_state(socket, &put_in(&1, keys, value))
  end

  @doc """
  Update Rephex state by `update_in/3`.

  Example:
  ```ex
  import Rephex.State.Assigns

  def mlt_count(socket, %{mlt: mlt} = _payload) do
    update_state_in(socket, [:count], &(&1 * mlt))
  end
  ```
  """
  def update_state_in(%Socket{parent_pid: parent_pid}, _keys, _fun) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def update_state_in(%Socket{} = socket, keys, fun) when is_list(keys) and is_function(fun, 1) do
    update_state(socket, &update_in(&1, keys, fun))
  end

  def get_state(%Socket{parent_pid: parent_pid}) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def get_state(%Socket{} = socket) do
    socket.assigns[@root]
  end

  def get_state_in(%Socket{parent_pid: parent_pid}, _keys) when parent_pid != nil,
    do: raise("Use this function only in LiveView (root).")

  def get_state_in(%Socket{} = socket, keys) when is_list(keys) do
    get_state(socket) |> get_in(keys)
  end
end
