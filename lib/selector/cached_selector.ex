defmodule Rephex.CachedSelector.Support do
  def default_args(socket) do
    [socket]
  end

  def default_fun(_args) do
    nil
  end
end

defmodule Rephex.CachedSelector.Base do
  alias Phoenix.LiveView.Socket

  @type args :: any()
  @type result :: any()

  @callback args(socket :: Socket.t()) :: args()
  @callback resolve(args :: args()) :: result()
end

defmodule Rephex.CachedSelector do
  @moduledoc """
  Contain a function and its arguments. The function is called only when the arguments change.

  ```ex
  defmodule CachedSelectorImpl do
    @behaviour Rephex.CachedSelector.Base

    @impl true
    def args(socket) do
      {socket.assigns.a, socket.assigns.b}
    end

    @impl true
    def resolve({a, b}) do
      a + b
    end
  end

  defmodule AnyLiveComponent do
    ...

    alias Rephex.CachedSelector

    @initial_state %{
      ab_sum_selector: CachedSelector.new(CachedSelectorImpl)
    }

    @impl true
    def mount(socket) do
      {:ok, socket |> assign(@initial_state)}
    end

    @impl true
    def update(assigns, socket) do
      {:ok,
      socket
      |> propagate_rephex(assigns)
      |> CachedSelector.update_selectors_in_socket()}
    end

    @impl true
    def render(assigns) do
      ~H'''
      <div>
        <p>ab_sum: <%= @ab_sum_selector.result %></p>
      </div>
      '''
    end
  end
  ```
  """
  alias Phoenix.LiveView.Socket

  @enforce_keys [:selector_module]
  defstruct result: nil,
            prev_args: {},
            selector_module: nil

  @type t(args, result) :: %__MODULE__{
          result: result,
          prev_args: args,
          selector_module: module()
        }

  @spec new(module()) :: t(any(), any())
  def new(selector) do
    %__MODULE__{selector_module: selector}
  end

  @spec update(t(args, result), Socket.t()) :: t(args, result) when args: any(), result: any()
  def update(%__MODULE__{selector_module: module} = selector, %Socket{} = socket) do
    new_args = module.args(socket)

    if new_args == selector.prev_args do
      selector
    else
      result = module.resolve(new_args)
      %__MODULE__{selector | result: result, prev_args: new_args}
    end
  end

  @spec update_selectors_in_socket(Socket.t()) :: Socket.t()
  def update_selectors_in_socket(%Socket{} = socket) do
    updated_selectors =
      socket.assigns
      |> Stream.filter(fn {_k, v} -> is_struct(v, __MODULE__) end)
      |> Stream.map(fn {k, v} -> {k, update(v, socket)} end)
      |> Enum.into(%{})

    Phoenix.Component.assign(socket, updated_selectors)
  end
end

# defmodule Rephex.CachedSelector do
#   @moduledoc """
#   Contain a function and its arguments. The function is called only when the arguments change.

#   ```ex
#   defmodule AnyLiveComponent do
#     ...

#     alias Rephex.CachedSelector

#     @initial_state %{
#       ab_sum_selector:
#         CachedSelector.new(
#           fn socket -> [socket.assigns.a, socket.assigns.b] end,
#           fn [a, b] -> a + b end  # Called only when a or b changes.
#         )
#     }

#     @impl true
#     def mount(socket) do
#       {:ok, socket |> assign(@initial_state)}
#     end

#     @impl true
#     def update(assigns, socket) do
#       {:ok,
#       socket
#       |> propagate_rephex(assigns)
#       |> CachedSelector.update_selectors_in_socket()}
#     end
#   end
#   ```
#   """

#   defstruct args: &__MODULE__.Support.default_args/1,
#             fun: &__MODULE__.Support.default_fun/1,
#             result: nil,
#             prev_args: []

#   alias Phoenix.LiveView.Socket

#   @type args_fun :: (Socket.t() -> [any()])
#   @type t(result) :: %__MODULE__{
#           args: args_fun(),
#           fun: (any() -> result),
#           result: result,
#           prev_args: [any()]
#         }

#   @spec new(args_fun(), (any() -> any())) :: %__MODULE__{}
#   def new(args, fun) when is_function(args, 1) and is_function(fun, 1) do
#     %__MODULE__{args: args, fun: fun}
#   end

#   @spec update(t(result), Socket.t()) :: t(result) when result: any()
#   def update(%__MODULE__{} = selector, %Socket{} = socket) do
#     args = selector.args.(socket)

#     if args == selector.prev_args do
#       selector
#     else
#       result = selector.fun.(args)
#       %__MODULE__{selector | result: result, prev_args: args}
#     end
#   end

#   @spec update_selectors_in_socket(Socket.t()) :: Socket.t()
#   def update_selectors_in_socket(%Socket{} = socket) do
#     updated_selectors =
#       socket.assigns
#       |> Stream.filter(fn {_k, v} -> is_struct(v, __MODULE__) end)
#       |> Stream.map(fn {k, v} -> {k, update(v, socket)} end)
#       |> Enum.into(%{})

#     Phoenix.Component.assign(socket, updated_selectors)
#   end
# end
