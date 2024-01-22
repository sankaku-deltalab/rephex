defmodule Rephex.Selector.CachedSelector.Base do
  alias Phoenix.LiveView.Socket

  @type args :: any()
  @type result :: any()

  @callback args(socket :: Socket.t()) :: args()
  @callback resolve(args :: args()) :: result()
end

defmodule Rephex.Selector.CachedSelector do
  @moduledoc """
  Contain a function and its arguments. The function is called only when the arguments change.

  ```ex
  defmodule CachedSelectorImpl do
    @behaviour Rephex.Selector.CachedSelector.Base

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

    alias Rephex.Selector.CachedSelector

    @initial_state %{
      ab_sum_selector: CachedSelector.new(CachedSelectorImpl)
      # ab_sum_selector: CachedSelector.new(CachedSelectorImpl, init: 0)  # initial value is optional
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
  @spec new(module(), [{:init, result}]) :: t(any(), result) when result: any()
  def new(selector, opt \\ []) do
    init = Keyword.get(opt, :init, nil)
    %__MODULE__{selector_module: selector, result: init}
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
end

defimpl Rephex.Selectable, for: Rephex.Selector.CachedSelector do
  def update_in_socket(selector, socket, selectable_keys) do
    Rephex.Util.socket_update_in(socket, selectable_keys, fn _ ->
      Rephex.Selector.CachedSelector.update(selector, socket)
    end)
  end
end
