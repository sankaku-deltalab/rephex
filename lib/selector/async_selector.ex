defmodule Rephex.Selector.AsyncSelector.Base do
  alias Phoenix.LiveView.Socket

  @type args :: any()
  @type result :: any()

  @callback args(socket :: Socket.t()) :: args()
  @callback resolve(args :: args()) :: result()
end

defmodule Rephex.Selector.AsyncSelector.Handler do
  alias Phoenix.LiveView.Socket

  defmacro __using__(_opt \\ []) do
    quote do
      @dialyzer {:nowarn_function, handle_async: 3}

      @impl true
      def handle_async(
            {Rephex.Selector.AsyncSelector.Handler, _selector_keys} = name,
            result,
            socket
          ) do
        Rephex.Selector.AsyncSelector.Handler.handle_async_select_result(
          name,
          result,
          socket
        )
      end
    end
  end

  def start_async_by_selector(%Socket{} = socket, selector_keys, func)
      when is_function(func, 0) do
    Phoenix.LiveView.start_async(socket, {__MODULE__, selector_keys}, func)
  end

  def handle_async_select_result(
        {__MODULE__, selector_keys} = _name,
        result,
        %Socket{} = socket
      ) do
    {:noreply, Rephex.Selector.AsyncSelector.resolve_in_socket(socket, selector_keys, result)}
  end
end

defmodule Rephex.Selector.AsyncSelector do
  @moduledoc """
  Contain a function and its arguments. The function is called only when the arguments change.

  ```ex
  defmodule AsyncSelectorImpl do
    @behaviour Rephex.Selector.AsyncSelector.Base

    @impl true
    def args(socket) do
      {socket.assigns.a, socket.assigns.b}
    end

    @impl true
    def resolve({a, b}) do
      :timer.sleep(1000)
      a + b
    end
  end

  defmodule AnyLiveComponent do
    ...

    alias Phoenix.LiveView.AsyncResult
    # use Rephex.LiveView  # Use this in LiveView
    use Rephex.LiveComponent  # Use this in LiveComponent

    @initial_state %{
      ab_sum_selector: AsyncSelector.new(AsyncSelectorImpl, init: 0)
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
      |> AsyncSelector.update_selectors_in_socket()}
    end

    @impl true
    def render(assigns) do
      ~H'''
      <div>
        <p>ab_sum: <%= @ab_sum_selector.async.result %></p>
      </div>
      '''
    end
  end
  ```
  """
  alias Rephex.Selector.AsyncSelector
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket
  alias Rephex.Selector.AsyncSelector.Handler

  @enforce_keys [:selector_module]
  defstruct async: %AsyncResult{},
            prev_args: {AsyncSelector, :__undefined__},
            selector_module: nil

  @type async_result(result) :: %AsyncResult{result: result}
  @type t(args, result) :: %__MODULE__{
          async: async_result(result),
          prev_args: args,
          selector_module: module()
        }

  @spec new(module()) :: t(any(), any())
  @spec new(module(), [{:init, result}]) :: t(any(), result) when result: any()
  def new(selector, opt \\ []) do
    init = Keyword.get(opt, :init, nil)
    %__MODULE__{selector_module: selector, async: AsyncResult.ok(init)}
  end

  @spec update_in_socket(Socket.t(), [any()]) :: Socket.t()
  def update_in_socket(
        %Socket{} = socket,
        selector_keys
      ) do
    %__MODULE__{selector_module: module, async: async} =
      selector = get_in(socket.assigns, selector_keys)

    new_args = module.args(socket)

    cond do
      async.loading != nil ->
        socket

      new_args == selector.prev_args ->
        socket

      true ->
        selector = %__MODULE__{selector | prev_args: new_args, async: AsyncResult.loading(async)}

        socket
        |> socket_update_in(selector_keys, fn _ -> selector end)
        |> Handler.start_async_by_selector(selector_keys, fn -> module.resolve(new_args) end)
    end
  end

  @spec update_selectors_in_socket(Socket.t()) :: Socket.t()
  def update_selectors_in_socket(%Socket{} = socket) do
    socket.assigns
    |> Stream.filter(fn {_k, v} -> is_struct(v, __MODULE__) end)
    |> Enum.reduce(socket, fn {k, _v}, socket ->
      update_in_socket(socket, [k])
    end)
  end

  def resolve_in_socket(
        %Socket{} = socket,
        selector_keys,
        result
      ) do
    case result do
      {:ok, result} ->
        socket
        |> socket_update_in(selector_keys, fn %__MODULE__{async: async} = selector ->
          %__MODULE__{selector | async: AsyncResult.ok(async, result)}
        end)

      {:exit, reason} ->
        socket
        |> socket_update_in(selector_keys, fn %__MODULE__{async: async} = selector ->
          %__MODULE__{selector | async: AsyncResult.failed(async, reason)}
        end)
    end
    # Run next async if args changed
    |> update_in_socket(selector_keys)
  end

  defp socket_update_in(socket, keys, func) do
    case keys do
      [single_key] ->
        Phoenix.Component.update(socket, single_key, func)

      [k, rest] ->
        Phoenix.Component.assign(socket, k, %{k => update_in(socket, rest, func)})
    end
  end
end
