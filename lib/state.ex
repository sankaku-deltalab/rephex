defmodule Rephex.State do
  @type t :: %__MODULE__{
          root?: boolean(),
          slices: %{atom() => map()}
        }

  defstruct root?: true, slices: %{}

  defmacro __using__([slices: slices] = _opt) when is_list(slices) do
    quote do
      alias Rephex.State.Support
      alias Phoenix.LiveView.Socket

      @__slices unquote(slices)
      @__async_modules Support.collect_async_modules(@__slices)

      @spec init(Socket.t()) :: Socket.t()
      def init(%Socket{} = socket) do
        Support.init_state(socket, @__slices)
      end

      @spec slice_modules() :: [module()]
      def slice_modules(), do: @__slices
    end
  end

  @spec propagate(t()) :: t()
  def propagate(%__MODULE__{} = rephex_state), do: %{rephex_state | root?: false}
end

defmodule Rephex.State.Support do
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  @type slice_state :: map()
  @type async_module :: module()

  @spec init_state(Socket.t(), [module()]) :: Socket.t()
  def init_state(%Socket{} = socket, slice_modules) do
    slices =
      slice_modules
      |> Enum.map(fn module ->
        %{initial_state: initial_state} = module.slice_info()
        {module, initial_state}
      end)
      |> Map.new()

    socket
    |> Phoenix.Component.assign(@root, %Rephex.State{root?: true, slices: slices})
  end

  @spec collect_async_modules([module()]) :: MapSet.t()
  def collect_async_modules(slice_modules) do
    slice_modules
    |> get_async_module_to_slice_map()
    |> Map.keys()
    |> MapSet.new()
  end

  @spec get_async_module_to_slice_map([module()]) :: %{module() => module()}
  def get_async_module_to_slice_map(slice_modules) do
    slice_modules
    |> Enum.flat_map(fn slice_module ->
      %{async_modules: async_modules} = slice_module.slice_info()
      Enum.map(async_modules, fn async_module -> {async_module, slice_module} end)
    end)
    |> Map.new()
  end

  @spec get_slice(Socket.t(), atom()) :: map()
  def get_slice(%Socket{} = socket, slice_module) when is_atom(slice_module) do
    get_slice_from_root(socket.assigns[@root], slice_module)
  end

  @spec put_slice(Socket.t(), atom(), slice_state()) :: Socket.t()
  def put_slice(%Socket{} = socket, slice_module, %{} = state) when is_atom(slice_module) do
    if propagated?(socket), do: raise("Must not mutate propagated state.")

    Phoenix.Component.update(socket, @root, fn %Rephex.State{slices: slices} = root ->
      slices = Map.put(slices, slice_module, state)
      %Rephex.State{root | slices: slices}
    end)
  end

  @spec update_slice(Socket.t(), atom(), (slice_state() -> slice_state())) :: map()
  def update_slice(%Socket{} = socket, slice_module, fun)
      when is_atom(slice_module) and is_function(fun, 1) do
    if propagated?(socket), do: raise("Must not mutate propagated state.")

    Phoenix.Component.update(socket, @root, fn %Rephex.State{slices: slices} = root ->
      slices = Map.update!(slices, slice_module, fun)
      %Rephex.State{root | slices: slices}
    end)
  end

  @spec get_slice_from_root(Rephex.State.t(), atom()) :: map()
  def get_slice_from_root(%Rephex.State{} = root_state, slice_module)
      when is_atom(slice_module) do
    %Rephex.State{slices: slices} = root_state
    Map.fetch!(slices, slice_module)
  end

  @spec propagated?(Socket.t()) :: boolean()
  def propagated?(%Socket{} = socket), do: not socket.assigns[@root].root?
end
