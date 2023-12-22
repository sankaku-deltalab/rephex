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

      def resolve_async(%Socket{} = socket, name, result) do
        Support.resolve_async(socket, @__async_modules, name, result)
      end
    end
  end

  @spec propagate(t()) :: t()
  def propagate(%__MODULE__{} = rephex_state), do: %{rephex_state | root?: false}
end

defmodule Rephex.State.Support do
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  @type slice_state :: map()

  @spec init_state(Socket.t(), [module()]) :: Socket.t()
  def init_state(%Socket{} = socket, slice_modules) do
    slices =
      slice_modules
      |> Enum.map(fn module ->
        %{name: name, initial_state: initial_state} = module.slice_info()
        {name, initial_state}
      end)
      |> Map.new()

    socket
    |> Phoenix.Component.assign(@root, %Rephex.State{root?: true, slices: slices})
  end

  @spec collect_async_modules([module()]) :: MapSet.t()
  def collect_async_modules(slice_modules) do
    slice_modules
    |> Enum.flat_map(fn module ->
      %{async_modules: async_modules} = module.slice_info()
      async_modules
    end)
    |> MapSet.new()
  end

  @spec resolve_async(Socket.t(), MapSet.t(), atom(), any()) :: any()
  def resolve_async(%Socket{} = socket, %MapSet{} = async_modules, name, result) do
    if propagated?(socket), do: raise("Must not resolve async on propagated state.")

    if name in async_modules do
      name.resolve(socket, result)
    else
      raise {:not_async_module, name}
    end
  end

  @spec get_slice(Socket.t(), atom()) :: map()
  def get_slice(%Socket{} = socket, slice_name) when is_atom(slice_name) do
    %Rephex.State{slices: slices} = socket.assigns[@root]
    Map.fetch!(slices, slice_name)
  end

  @spec put_slice(Socket.t(), atom(), slice_state()) :: Socket.t()
  def put_slice(%Socket{} = socket, slice_name, %{} = state) when is_atom(slice_name) do
    if propagated?(socket), do: raise("Must not mutate propagated state.")

    Phoenix.Component.update(socket, @root, fn %Rephex.State{slices: slices} = root ->
      slices = Map.put(slices, slice_name, state)
      %Rephex.State{root | slices: slices}
    end)
  end

  @spec update_slice(Socket.t(), atom(), (slice_state() -> slice_state())) :: map()
  def update_slice(%Socket{} = socket, slice_name, fun)
      when is_atom(slice_name) and is_function(fun, 1) do
    if propagated?(socket), do: raise("Must not mutate propagated state.")

    Phoenix.Component.update(socket, @root, fn %Rephex.State{slices: slices} = root ->
      slices = Map.update!(slices, slice_name, fun)
      %Rephex.State{root | slices: slices}
    end)
  end

  @spec get_slice_from_root(Rephex.State.t(), atom()) :: map()
  def get_slice_from_root(%Rephex.State{} = root_state, slice_name) when is_atom(slice_name) do
    %Rephex.State{slices: slices} = root_state
    Map.fetch!(slices, slice_name)
  end

  @spec propagated?(Socket.t()) :: boolean()
  def propagated?(%Socket{} = socket), do: not socket.assigns[@root].root?
end
